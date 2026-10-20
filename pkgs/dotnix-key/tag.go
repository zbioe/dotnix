package main

import (
	"crypto/hmac"
	"crypto/sha512"
	"encoding/binary"
)

// In the gap: key then tag, at a random 512-byte step, the rest random too.
const (
	keySize   = 4096
	tagSize   = sha512.Size
	blockSize = keySize + tagSize
	step      = 512
)

// tag needs the key itself: without it the gap is just noise.
func tag(key []byte, uuid string, slot int, pin bool) []byte {
	m := hmac.New(sha512.New, key)
	tagInto(m, uuid, slot, pin)
	return m.Sum(nil)
}

type hasher interface {
	Write([]byte) (int, error)
	Sum([]byte) []byte
	Reset()
}

func tagInto(m hasher, uuid string, slot int, pin bool) {
	var b [2]byte
	b[0] = byte(slot)
	if pin {
		b[1] = 1
	}
	m.Write([]byte("dotnix"))
	var n [2]byte
	binary.BigEndian.PutUint16(n[:], uint16(len(uuid)))
	m.Write(n[:])
	m.Write([]byte(uuid))
	m.Write(b[:])
}

type found struct {
	Pos  int // offset in the gap
	Key  []byte
	Slot int
	PIN  bool
}

// find looks for a key of volume uuid anywhere in gap.
func find(gap []byte, uuid string) (found, bool) {
	var sum [tagSize]byte
	for pos := 0; pos+blockSize <= len(gap); pos += step {
		key := gap[pos : pos+keySize]
		want := gap[pos+keySize : pos+blockSize]
		m := hmac.New(sha512.New, key)
		for slot := range maxSlots {
			for _, pin := range []bool{false, true} {
				m.Reset()
				tagInto(m, uuid, slot, pin)
				if hmac.Equal(m.Sum(sum[:0]), want) {
					return found{Pos: pos, Key: append([]byte{}, key...), Slot: slot, PIN: pin}, true
				}
			}
		}
	}
	return found{}, false
}

// secret is what LUKS is given: the key, then the PIN if any.
func secret(key []byte, pin string) []byte {
	return append(append([]byte{}, key...), pin...)
}
