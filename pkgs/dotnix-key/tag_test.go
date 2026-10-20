package main

import (
	"bytes"
	"crypto/rand"
	"testing"
	"time"
)

func noise(n int) []byte {
	b := make([]byte, n)
	rand.Read(b)
	return b
}

func place(gap []byte, pos int, key []byte, uuid string, slot int, pin bool) {
	copy(gap[pos:], key)
	copy(gap[pos+keySize:], tag(key, uuid, slot, pin))
}

func TestFindEverywhere(t *testing.T) {
	gap := noise(64 << 10)
	key := noise(keySize)
	for _, pos := range []int{0, step, 7 * step, len(gap) - blockSize - (len(gap)-blockSize)%step} {
		for _, slot := range []int{0, 5, maxSlots - 1} {
			for _, pin := range []bool{false, true} {
				g := append([]byte{}, gap...)
				place(g, pos, key, "u-1", slot, pin)
				f, ok := find(g, "u-1")
				if !ok || f.Pos != pos || f.Slot != slot || f.PIN != pin || !bytes.Equal(f.Key, key) {
					t.Fatalf("pos %d slot %d pin %v: %+v %v", pos, slot, pin, f, ok)
				}
			}
		}
	}
}

func TestFindRejects(t *testing.T) {
	key := noise(keySize)
	gap := noise(32 << 10)
	place(gap, 4*step, key, "mine", 3, false)
	if _, ok := find(gap, "other"); ok {
		t.Error("found for another volume")
	}
	for _, off := range []int{4 * step, 4*step + keySize - 1, 4*step + keySize, 4*step + blockSize - 1} {
		g := append([]byte{}, gap...)
		g[off] ^= 1
		if _, ok := find(g, "mine"); ok {
			t.Errorf("a flipped byte at %d went unnoticed", off)
		}
	}
	g := make([]byte, len(gap))
	copy(g[4*step+1:], gap[4*step:4*step+blockSize])
	if _, ok := find(g, "mine"); ok {
		t.Error("found off the 512-byte steps")
	}
	for name, g := range map[string][]byte{"zeros": make([]byte, 1<<20), "noise": noise(1 << 20), "short": gap[:blockSize-1]} {
		if _, ok := find(g, "mine"); ok {
			t.Errorf("%s: found a key", name)
		}
	}
}

func TestFindDistinctTags(t *testing.T) {
	key := noise(keySize)
	seen := map[string]bool{}
	for _, uuid := range []string{"a", "b", "ab"} {
		for slot := range maxSlots {
			for _, pin := range []bool{false, true} {
				s := string(tag(key, uuid, slot, pin))
				if seen[s] {
					t.Fatalf("tag repeated for %s/%d/%v", uuid, slot, pin)
				}
				seen[s] = true
			}
		}
	}
	if len(tag(key, "a", 0, false)) != 64 {
		t.Error("tag is not 64 bytes")
	}
}

func TestFindSpeed(t *testing.T) {
	gap := noise(maxGapEnd)
	start := time.Now()
	find(gap, "8e7e951a-5b4c-4bfe-92f2-57d1f88da1d7")
	took := time.Since(start)
	t.Logf("a 2 MiB gap without a key: %v", took)
	if took > 2*time.Second {
		t.Errorf("too slow for the boot: %v", took)
	}
}

func TestSecret(t *testing.T) {
	key := []byte{1, 2}
	if s := secret(key, "34"); !bytes.Equal(s, []byte{1, 2, '3', '4'}) || !bytes.Equal(key, []byte{1, 2}) {
		t.Errorf("secret %v, key %v", s, key)
	}
}
