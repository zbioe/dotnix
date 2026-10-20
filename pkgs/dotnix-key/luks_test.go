package main

import (
	"bytes"
	"errors"
	"os"
	"testing"
)

func TestLUKSReal(t *testing.T) {
	for _, version := range []string{"luks1", "luks2"} {
		t.Run(version, func(t *testing.T) {
			path := luksFile(t, version)
			info, err := readLUKS(path)
			if err != nil {
				t.Fatal(err)
			}
			if want := sh(t, "", "cryptsetup", "luksUUID", path); info.UUID != want {
				t.Errorf("UUID %q, cryptsetup says %q", info.UUID, want)
			}
			if !info.Used[0] || len(info.Used) != 1 {
				t.Errorf("used slots %v, want only 0", info.Used)
			}
			if slot, _ := info.freeSlot(); slot != 1 {
				t.Errorf("free slot %d, want 1", slot)
			}
			newKey := emptyFile(t, 0)
			os.WriteFile(newKey, []byte("other"), 0o600)
			sh(t, "pass", "cryptsetup", "-q", "luksAddKey", "--pbkdf", "pbkdf2", "--pbkdf-force-iterations", "1000",
				"--key-file", "-", "--new-key-slot", "5", path, newKey)
			info, _ = readLUKS(path)
			if !info.Used[0] || !info.Used[5] || len(info.Used) != 2 {
				t.Errorf("after adding slot 5: %v", info.Used)
			}
			sh(t, "", "cryptsetup", "-q", "luksKillSlot", path, "0")
			info, _ = readLUKS(path)
			if info.Used[0] || !info.Used[5] {
				t.Errorf("after killing slot 0: %v", info.Used)
			}
			if slot, _ := info.freeSlot(); slot != 0 {
				t.Errorf("free slot %d, want 0", slot)
			}
		})
	}
}

func TestLUKSFull(t *testing.T) {
	for _, l := range []luksInfo{{Version: 1, Used: map[int]bool{}}, {Version: 2, Used: map[int]bool{}}} {
		n := luks1Slots
		if l.Version == 2 {
			n = maxSlots
		}
		for i := range n {
			l.Used[i] = true
		}
		if _, err := l.freeSlot(); err == nil {
			t.Errorf("LUKS%d full but got a free slot", l.Version)
		}
	}
}

func TestLUKSRejects(t *testing.T) {
	path := luksFile(t, "luks2")
	good, _ := os.ReadFile(path)
	good = good[:luks2HeaderMax]
	corrupt := func(f func(b []byte)) []byte {
		b := append([]byte{}, good...)
		f(b)
		return b
	}
	cases := map[string][]byte{
		"empty":        {},
		"zeros":        make([]byte, 8192),
		"magic":        corrupt(func(b []byte) { b[0] = 'X' }),
		"version 9":    corrupt(func(b []byte) { b[7] = 9 }),
		"no uuid":      corrupt(func(b []byte) { copy(b[luksUUIDOffset:], make([]byte, uuidField)) }),
		"huge header":  corrupt(func(b []byte) { b[8] = 0xff }),
		"small header": corrupt(func(b []byte) { copy(b[8:16], make([]byte, 8)) }),
		"bad json":     corrupt(func(b []byte) { b[4096] = '!' }),
		"truncated":    good[:8192],
	}
	for name, b := range cases {
		if _, err := parseLUKS(bytes.NewReader(b)); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
	if _, err := parseLUKS(bytes.NewReader(make([]byte, 100))); !errors.Is(err, errNotLUKS) {
		t.Errorf("tiny non-LUKS: %v", err)
	}
}
