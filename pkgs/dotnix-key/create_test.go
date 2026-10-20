package main

import (
	"bytes"
	"crypto/rand"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

const mbr = "label: dos\nstart=2048, type=c\n"

func TestCreateAndUnlock(t *testing.T) {
	r := newRig(t, 512, mbr)
	before := r.read()
	r.mustCreate(false)
	r.sameOutsideGap(before)
	r.wantSlots(0, 1)
	_, gap := r.gap()
	if allZero(gap) || bytes.Count(gap, []byte{0}) > len(gap)/64 {
		t.Error("the gap is not all noise")
	}
	var out bytes.Buffer
	list(r.f.fs, &out)
	if !strings.Contains(out.String(), "opens "+r.dev("nvme0n1p2")+" (slot 1)") {
		t.Errorf("list: %s", out.String())
	}
	u, o, _ := r.unlocker()
	if !u.run(5 * time.Second) {
		t.Fatal("not unlocked")
	}
	if len(o.slots) != 1 || o.slots[0] != 1 {
		t.Errorf("opened %v, want slot 1 once", o.slots)
	}
}

func TestCreateRandomPlace(t *testing.T) {
	r := newRig(t, 512, mbr)
	places := map[int]bool{}
	for range 4 {
		r.mustCreate(false)
		_, gap := r.gap()
		f, ok := find(gap, mustUUID(t, r.luks))
		if !ok {
			t.Fatal("key not found")
		}
		places[f.Pos] = true
	}
	if len(places) < 2 {
		t.Errorf("the key always lands at the same place: %v", places)
	}
	r.wantSlots(0, 2)
}

func mustUUID(t *testing.T, luks string) string {
	info, err := readLUKS(luks)
	if err != nil {
		t.Fatal(err)
	}
	return info.UUID
}

func TestCreatePIN(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(true, "1234", "1234")
	r.wantSlots(0, 1)
	_, gap := r.gap()
	f, _ := find(gap, mustUUID(t, r.luks))
	if !f.PIN {
		t.Fatal("the tag does not say PIN")
	}
	if (cryptsetup{bin: "cryptsetup"}).testKey(r.luks, f.Key, 1) == nil {
		t.Fatal("the key opens without the PIN")
	}

	u, o, a := r.unlocker("1234")
	if !u.run(5*time.Second) || a.asked != 1 || len(o.slots) != 1 {
		t.Fatalf("right PIN: asked %d, opened %v", a.asked, o.slots)
	}
	u, o, a = r.unlocker("0000", "1111", "2222", "1234")
	if u.run(5*time.Second) || a.asked != pinTries || len(o.slots) != pinTries {
		t.Fatalf("wrong PINs: asked %d, opened %v", a.asked, o.slots)
	}
	u, o, a = r.unlocker("0000", "1234")
	if !u.run(5*time.Second) || a.asked != 2 {
		t.Fatalf("wrong then right: asked %d, opened %v", a.asked, o.slots)
	}
	u, o, a = r.unlocker("")
	if u.run(5*time.Second) || a.asked != 1 || len(o.slots) != 0 {
		t.Fatalf("empty PIN: asked %d, opened %v", a.asked, o.slots)
	}
	u, o, a = r.unlocker()
	if u.run(5*time.Second) || len(o.slots) != 0 {
		t.Fatalf("PIN prompt failing: asked %d, opened %v", a.asked, o.slots)
	}
}

func TestCreatePINRules(t *testing.T) {
	r := newRig(t, 512, mbr)
	for _, answers := range [][]string{{"123", "123"}, {"1234", "1235"}, {""}} {
		c, _ := r.creator(answers...)
		if err := c.create(r.dev("sda"), r.dev("nvme0n1p2"), true); err == nil {
			t.Errorf("PIN %v accepted", answers)
		}
	}
	r.wantSlots(0)
}

func TestCreateReplaceRevokes(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	_, gap := r.gap()
	old, _ := find(gap, mustUUID(t, r.luks))
	out := r.mustCreate(false)
	if !strings.Contains(out, "Revoked slot 1") {
		t.Errorf("output: %s", out)
	}
	r.wantSlots(0, 2)
	if (cryptsetup{bin: "cryptsetup"}).testKey(r.luks, old.Key, 1) == nil {
		t.Error("the old key still opens")
	}
	if u, _, _ := r.unlocker(); !u.run(5 * time.Second) {
		t.Error("the new key does not unlock")
	}
}

func TestCreateReplacePINKey(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(true, "1234", "1234")
	r.mustCreate(false, "")
	r.wantSlots(0, 1, 2)

	r2 := newRig(t, 512, mbr)
	r2.mustCreate(true, "1234", "1234")
	out := r2.mustCreate(false, "1234")
	if !strings.Contains(out, "Revoked slot 1") {
		t.Errorf("output: %s", out)
	}
	r2.wantSlots(0, 2)

	r3 := newRig(t, 512, mbr)
	r3.mustCreate(true, "1234", "1234")
	out = r3.mustCreate(false, "9999")
	if !strings.Contains(out, "slot is kept") {
		t.Errorf("output: %s", out)
	}
	r3.wantSlots(0, 1, 2)
}

func TestCreateRefusesForeignGap(t *testing.T) {
	r := newRig(t, 512, mbr)
	raw := r.read()
	copy(raw[512:], "GRUB core.img")
	os.WriteFile(r.stick, raw, 0o600)
	c, _ := r.creator()
	err := c.create(r.dev("sda"), r.dev("nvme0n1p2"), false)
	if err == nil || !strings.Contains(err.Error(), "-force") {
		t.Fatalf("foreign data: %v", err)
	}
	r.wantSlots(0)
	c, _ = r.creator()
	c.force = true
	if err := c.create(r.dev("sda"), r.dev("nvme0n1p2"), false); err != nil {
		t.Fatal(err)
	}
	r.wantSlots(0, 1)
}

func TestCreateRefuses(t *testing.T) {
	r := newRig(t, 512, mbr)
	for name, dev := range map[string]string{
		"a partition":        r.dev("nvme0n1p2"),
		"the LUKS disk":      r.dev("nvme0n1"),
		"not a block device": r.dev("nope"),
	} {
		c, _ := r.creator()
		if err := c.create(dev, r.dev("nvme0n1p2"), false); err == nil {
			t.Errorf("%s accepted", name)
		}
	}
	c, _ := r.creator()
	if err := c.create(r.dev("sda"), "", false); err == nil || !strings.Contains(err.Error(), "-luks") {
		t.Errorf("two LUKS volumes without -luks: %v", err)
	}
	r.wantSlots(0)
}

func TestCreateGPT(t *testing.T) {
	for _, ss := range []int{512, 4096} {
		unit := (1 << 20) / ss
		r := newRig(t, ss, "label: gpt\nstart="+strconv.Itoa(unit)+", size="+strconv.Itoa(4*unit)+", name=\"MUSIC\"\n")
		before := r.read()
		dump := sh(t, "", "sfdisk", "--dump", "--sector-size", strconv.Itoa(ss), r.stick)
		r.mustCreate(false)
		r.sameOutsideGap(before)
		if got := sh(t, "", "sfdisk", "--dump", "--sector-size", strconv.Itoa(ss), r.stick); got != dump {
			t.Errorf("ss %d: partition table changed:\n%s\n%s", ss, dump, got)
		}
		sh(t, "", "sfdisk", "--verify", "--sector-size", strconv.Itoa(ss), r.stick)
		if u, _, _ := r.unlocker(); !u.run(5 * time.Second) {
			t.Errorf("ss %d: not unlocked", ss)
		}
	}
}

func TestAdopt(t *testing.T) {
	r := newRig(t, 512, "label: dos\nstart=3616, type=7\n")
	legacy := make([]byte, keySize)
	rand.Read(legacy)
	raw := r.read()
	copy(raw[2048:], legacy)
	os.WriteFile(r.stick, raw, 0o600)
	keyFile := emptyFile(t, 0)
	os.WriteFile(keyFile, legacy, 0o600)
	decoy := emptyFile(t, 0)
	os.WriteFile(decoy, []byte("decoy"), 0o600)
	add := func(slot, file string) {
		sh(t, "pass", "cryptsetup", "-q", "luksAddKey", "--pbkdf", "pbkdf2", "--pbkdf-force-iterations", "1000",
			"--key-file", "-", "--new-key-slot", slot, r.luks, file)
	}
	add("1", decoy)
	add("2", keyFile)

	before := r.read()
	c, out := r.creator()
	if err := c.adopt(r.dev("sda"), r.dev("nvme0n1p2"), 2048); err != nil {
		t.Fatalf("%v\n%s", err, out)
	}
	r.sameOutsideGap(before)
	r.wantSlots(0, 1, 2)
	_, gap := r.gap()
	f, ok := find(gap, mustUUID(t, r.luks))
	if !ok || f.Slot != 2 || f.PIN || !bytes.Equal(f.Key, legacy) {
		t.Fatalf("adopted: %+v %v", f, ok)
	}
	u, o, _ := r.unlocker()
	if !u.run(5*time.Second) || len(o.slots) != 1 || o.slots[0] != 2 {
		t.Fatalf("unlock after adopt: %v", o.slots)
	}
	c, _ = r.creator()
	if err := c.adopt(r.dev("sda"), r.dev("nvme0n1p2"), 2048); err == nil {
		t.Error("adopted twice")
	}
}

func TestAdoptRejects(t *testing.T) {
	r := newRig(t, 512, mbr)
	for name, off := range map[string]int64{"zeros": 2048, "before the gap": 0, "past the gap": 1 << 20} {
		c, _ := r.creator()
		if err := c.adopt(r.dev("sda"), r.dev("nvme0n1p2"), off); err == nil {
			t.Errorf("%s accepted", name)
		}
	}
	raw := r.read()
	junk := make([]byte, keySize)
	rand.Read(junk)
	copy(raw[2048:], junk)
	os.WriteFile(r.stick, raw, 0o600)
	before := r.read()
	c, _ := r.creator()
	if err := c.adopt(r.dev("sda"), r.dev("nvme0n1p2"), 2048); err == nil || !strings.Contains(err.Error(), "does not open") {
		t.Errorf("a key LUKS doesn't know: %v", err)
	}
	if !bytes.Equal(before, r.read()) {
		t.Error("a refused adopt changed the stick")
	}
}
