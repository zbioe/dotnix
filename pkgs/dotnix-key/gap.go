package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"hash/crc32"
	"io"
	"os"
)

// The gap: after the partition table, before the first partition (as the kernel sees them).
const maxGapEnd = 2 << 20

var errNoGap = errors.New("no usable gap")

type gapRange struct{ Start, End int64 }

func (g gapRange) size() int64 { return g.End - g.Start }

// gapOf needs the disk's partitions as the kernel lists them (no partition table, no gap).
func gapOf(r io.ReaderAt, sectorSize uint64, parts []blockDev) (gapRange, error) {
	if len(parts) == 0 {
		return gapRange{}, fmt.Errorf("%w: no partitions", errNoGap)
	}
	first := parts[0].Start
	for _, p := range parts {
		first = min(first, p.Start)
	}
	ss := int64(sectorSize)
	mbr := make([]byte, ss)
	if _, err := r.ReadAt(mbr, 0); err != nil {
		return gapRange{}, err
	}
	if mbr[510] != 0x55 || mbr[511] != 0xAA {
		return gapRange{}, fmt.Errorf("%w: no MBR or GPT", errNoGap)
	}
	g := gapRange{Start: ss, End: min(int64(first)*512, maxGapEnd)}
	hdr := make([]byte, ss)
	if _, err := r.ReadAt(hdr, ss); err != nil {
		return gapRange{}, err
	}
	if bytes.HasPrefix(hdr, []byte("EFI PART")) {
		end, err := gptEntriesEnd(hdr, ss)
		if err != nil {
			return gapRange{}, err
		}
		g.Start = (end + ss - 1) / ss * ss
	}
	if g.size() < blockSize {
		return gapRange{}, fmt.Errorf("%w: %d bytes free before the first partition", errNoGap, max(g.size(), 0))
	}
	return g, nil
}

// gptEntriesEnd is where the GPT partition entries end, in bytes.
func gptEntriesEnd(hdr []byte, ss int64) (int64, error) {
	size := binary.LittleEndian.Uint32(hdr[12:16])
	if size < 92 || int64(size) > ss {
		return 0, fmt.Errorf("GPT header size %d", size)
	}
	check := append([]byte{}, hdr[:size]...)
	binary.LittleEndian.PutUint32(check[16:20], 0)
	if crc32.ChecksumIEEE(check) != binary.LittleEndian.Uint32(hdr[16:20]) {
		return 0, errors.New("GPT header checksum mismatch")
	}
	lba := binary.LittleEndian.Uint64(hdr[72:80])
	count := binary.LittleEndian.Uint32(hdr[80:84])
	entrySize := binary.LittleEndian.Uint32(hdr[84:88])
	if lba < 2 || lba > 1<<20 || count == 0 || count > 1<<16 || entrySize < 128 || entrySize > 4096 {
		return 0, fmt.Errorf("GPT entries: %d of %d bytes at LBA %d", count, entrySize, lba)
	}
	return int64(lba)*ss + int64(count)*int64(entrySize), nil
}

// diskGap opens a whole disk and returns its gap and what is in it.
func (s sysfs) diskGap(disk blockDev, devs []blockDev) (gapRange, []byte, error) {
	f, err := os.Open(disk.Path)
	if err != nil {
		return gapRange{}, nil, err
	}
	defer f.Close()
	g, err := gapOf(f, s.logicalSectorSize(disk.Name), partsOf(devs, disk.Name))
	if err != nil {
		return gapRange{}, nil, err
	}
	buf := make([]byte, g.size())
	if _, err := f.ReadAt(buf, g.Start); err != nil {
		return gapRange{}, nil, err
	}
	return g, buf, nil
}

func allZero(b []byte) bool {
	for _, c := range b {
		if c != 0 {
			return false
		}
	}
	return true
}
