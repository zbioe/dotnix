package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"os"
	"strconv"
	"testing"
)

// image partitions a file with sfdisk; parts come back in kernel units (512 bytes).
func image(t *testing.T, size int64, ss int, script string) (string, []blockDev) {
	t.Helper()
	need(t, "sfdisk")
	path := emptyFile(t, size)
	sh(t, script, "sfdisk", "--quiet", "--sector-size", strconv.Itoa(ss), path)
	return path, imageParts(t, path, ss)
}

func imageParts(t *testing.T, path string, ss int) []blockDev {
	t.Helper()
	out := sh(t, "", "sfdisk", "--dump", "--sector-size", strconv.Itoa(ss), path)
	var parts []blockDev
	for _, line := range bytes.Split([]byte(out), []byte("\n")) {
		_, rest, ok := bytes.Cut(line, []byte("start="))
		if !ok {
			continue
		}
		num, _, _ := bytes.Cut(rest, []byte(","))
		n, err := strconv.ParseUint(string(bytes.TrimSpace(num)), 10, 64)
		if err != nil {
			t.Fatal(err)
		}
		parts = append(parts, blockDev{Partition: true, Start: n * uint64(ss) / 512})
	}
	return parts
}

func gapOfFile(t *testing.T, path string, ss int, parts []blockDev) (gapRange, error) {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	return gapOf(f, uint64(ss), parts)
}

func TestGapMBR(t *testing.T) {
	for _, tc := range []struct {
		ss, start int
		want      gapRange
	}{
		{512, 2048, gapRange{512, 1 << 20}},
		{512, 3616, gapRange{512, 3616 * 512}},
		{512, 8192, gapRange{512, maxGapEnd}},
		{4096, 256, gapRange{4096, 1 << 20}},
	} {
		path, parts := image(t, 16<<20, tc.ss, "label: dos\nstart="+strconv.Itoa(tc.start)+", type=83\n")
		g, err := gapOfFile(t, path, tc.ss, parts)
		if err != nil || g != tc.want {
			t.Errorf("ss %d start %d: %v %v, want %v", tc.ss, tc.start, g, err, tc.want)
		}
	}
}

func TestGapGPT(t *testing.T) {
	for _, ss := range []int{512, 4096} {
		unit := (1 << 20) / ss
		path, parts := image(t, 16<<20, ss, "label: gpt\nstart="+strconv.Itoa(unit)+", size="+strconv.Itoa(unit)+"\n")
		g, err := gapOfFile(t, path, ss, parts)
		if err != nil {
			t.Fatal(err)
		}
		raw, _ := os.ReadFile(path)
		hdr := raw[ss : 2*ss]
		entriesEnd := int64(binary.LittleEndian.Uint64(hdr[72:80]))*int64(ss) +
			int64(binary.LittleEndian.Uint32(hdr[80:84]))*int64(binary.LittleEndian.Uint32(hdr[84:88]))
		if g.Start < entriesEnd || g.Start%int64(ss) != 0 || g.End != 1<<20 {
			t.Errorf("ss %d: gap %v, entries end at %d", ss, g, entriesEnd)
		}
	}
}

func TestGapRejects(t *testing.T) {
	need(t, "sfdisk", "mkfs.vfat")
	path, parts := image(t, 16<<20, 512, "label: dos\nstart=2048, type=83\n")
	if _, err := gapOfFile(t, path, 512, nil); !errors.Is(err, errNoGap) {
		t.Errorf("no partitions: %v", err)
	}

	small, sparts := image(t, 16<<20, 512, "label: dos\nstart=8, type=83\n")
	if _, err := gapOfFile(t, small, 512, sparts); !errors.Is(err, errNoGap) {
		t.Errorf("4 KiB gap: %v", err)
	}

	fat := emptyFile(t, 16<<20)
	sh(t, "", "mkfs.vfat", fat)
	if _, err := gapOfFile(t, fat, 512, nil); !errors.Is(err, errNoGap) {
		t.Errorf("FAT without a partition table: %v", err)
	}

	blank := emptyFile(t, 16<<20)
	if _, err := gapOfFile(t, blank, 512, parts); !errors.Is(err, errNoGap) {
		t.Errorf("blank disk: %v", err)
	}

	gpt, gparts := image(t, 16<<20, 512, "label: gpt\nstart=2048, size=2048\n")
	raw, _ := os.ReadFile(gpt)
	raw[512+80] ^= 0xff
	os.WriteFile(gpt, raw, 0o600)
	if _, err := gapOfFile(t, gpt, 512, gparts); err == nil {
		t.Error("corrupt GPT header accepted")
	}
}
