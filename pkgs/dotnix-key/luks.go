package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
)

const (
	luksMagic       = "LUKS\xba\xbe"
	luksUUIDOffset  = 168
	uuidField       = 40
	luks1SlotOffset = 208
	luks1SlotSize   = 48
	luks1Slots      = 8
	luks1Active     = 0x00AC71F3
	luks2HeaderMin  = 16 << 10
	luks2HeaderMax  = 4 << 20
	maxSlots        = 32
)

var errNotLUKS = errors.New("not a LUKS volume")

type luksInfo struct {
	Version int
	UUID    string
	Used    map[int]bool
}

func readLUKS(path string) (luksInfo, error) {
	f, err := os.Open(path)
	if err != nil {
		return luksInfo{}, err
	}
	defer f.Close()
	return parseLUKS(f)
}

func parseLUKS(r io.ReaderAt) (luksInfo, error) {
	hdr := make([]byte, 4096)
	if _, err := r.ReadAt(hdr, 0); err != nil && !errors.Is(err, io.EOF) {
		return luksInfo{}, err
	}
	if !bytes.HasPrefix(hdr, []byte(luksMagic)) {
		return luksInfo{}, errNotLUKS
	}
	info := luksInfo{
		Version: int(binary.BigEndian.Uint16(hdr[6:8])),
		UUID:    string(bytes.TrimRight(hdr[luksUUIDOffset:luksUUIDOffset+uuidField], "\x00")),
		Used:    map[int]bool{},
	}
	if info.UUID == "" {
		return luksInfo{}, fmt.Errorf("%w (no UUID)", errNotLUKS)
	}
	switch info.Version {
	case 1:
		for i := range luks1Slots {
			off := luks1SlotOffset + i*luks1SlotSize
			if binary.BigEndian.Uint32(hdr[off:off+4]) == luks1Active {
				info.Used[i] = true
			}
		}
	case 2:
		size := binary.BigEndian.Uint64(hdr[8:16])
		if size < luks2HeaderMin || size > luks2HeaderMax {
			return luksInfo{}, fmt.Errorf("LUKS2 header size %d out of range", size)
		}
		area := make([]byte, size-4096)
		if _, err := r.ReadAt(area, 4096); err != nil {
			return luksInfo{}, fmt.Errorf("LUKS2 metadata: %w", err)
		}
		var meta struct {
			Keyslots map[string]json.RawMessage `json:"keyslots"`
		}
		if err := json.Unmarshal(bytes.TrimRight(area, "\x00"), &meta); err != nil {
			return luksInfo{}, fmt.Errorf("LUKS2 metadata: %w", err)
		}
		for k := range meta.Keyslots {
			n, err := strconv.Atoi(k)
			if err != nil || n < 0 || n >= maxSlots {
				return luksInfo{}, fmt.Errorf("LUKS2 metadata: bad key slot %q", k)
			}
			info.Used[n] = true
		}
	default:
		return luksInfo{}, fmt.Errorf("unsupported LUKS version %d", info.Version)
	}
	return info, nil
}

func (l luksInfo) freeSlot() (int, error) {
	n := maxSlots
	if l.Version == 1 {
		n = luks1Slots
	}
	for i := range n {
		if !l.Used[i] {
			return i, nil
		}
	}
	return 0, errors.New("no free key slot")
}
