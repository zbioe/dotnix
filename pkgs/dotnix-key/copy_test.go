package main

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func (r *rig) export() string {
	r.t.Helper()
	c, out := r.creator()
	if err := c.export(r.dev("sda"), r.dev("nvme0n1p2")); err != nil {
		r.t.Fatalf("export: %v", err)
	}
	return out.String()
}

// reformat: the stick made again, as usb-stick create does (the gap lost)
func (r *rig) reformat(script string) {
	r.unplug()
	r.stick, r.parts = image(r.t, 16<<20, r.ss, script)
	r.plug()
}

func TestExportImportSameKey(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	key := r.export()
	r.reformat("label: gpt\nstart=2048, type=L\n")
	if _, ok := find(func() []byte { _, g := r.gap(); return g }(), mustUUID(t, r.luks)); ok {
		t.Fatal("the reformatted stick still has the key")
	}
	before := r.read()
	c, out := r.creator()
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(key)); err != nil {
		t.Fatalf("import: %v\n%s", err, out)
	}
	r.sameOutsideGap(before)
	r.wantSlots(0, 1)
	u, o, _ := r.unlocker()
	if !u.run(5*time.Second) || len(o.slots) != 1 || o.slots[0] != 1 {
		t.Fatalf("not unlocked by the same slot: %v", o.slots)
	}
	if r.export() != key {
		t.Error("the imported key differs")
	}

	c, out = r.creator()
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(key)); err != nil || !strings.Contains(out.String(), "already holds") {
		t.Errorf("import again: %v\n%s", err, out)
	}
}

func TestImportPIN(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(true, "1234", "1234")
	key := r.export()
	r.reformat(mbr)
	c, _ := r.creator("4321")
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(key)); err == nil {
		t.Fatal("imported with a wrong PIN")
	}
	if _, g := r.gap(); !allZero(g) {
		t.Fatal("the gap changed on a wrong PIN")
	}
	c, out := r.creator("1234")
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(key)); err != nil {
		t.Fatalf("import: %v\n%s", err, out)
	}
	r.wantSlots(0, 1)
	u, _, a := r.unlocker("1234")
	if !u.run(5*time.Second) || a.asked != 1 {
		t.Fatal("not unlocked with the PIN")
	}
}

func TestImportRefuses(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	key := r.export()
	// another volume's
	c, _ := r.creator()
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p3"), strings.NewReader(key)); err == nil {
		t.Error("imported a key of another volume")
	}
	// damaged
	bad := strings.Replace(key, "dotnix-key-v1", "dotnix-key-v0", 1)
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(bad)); err == nil {
		t.Error("imported a damaged key")
	}
	// a slot it doesn't open
	f := strings.Fields(key)
	f[2] = "0"
	if err := c.importKey(r.dev("sda"), r.dev("nvme0n1p2"), strings.NewReader(strings.Join(f, " "))); err == nil {
		t.Error("imported a key for a slot it doesn't open")
	}
	if !bytes.Equal([]byte(r.export()), []byte(key)) {
		t.Error("a refused import changed the stick")
	}
	r.wantSlots(0, 1)
}
