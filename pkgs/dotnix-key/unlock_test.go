package main

import (
	"testing"
	"time"
)

func TestUnlockNoStick(t *testing.T) {
	r := newRig(t, 512, mbr)
	u, o, a := r.unlocker()
	start := time.Now()
	ok := u.run(300 * time.Millisecond)
	took := time.Since(start)
	if ok || took < 300*time.Millisecond || took > 2*time.Second || len(o.slots) != 0 || a.asked != 0 {
		t.Fatalf("ok=%v after %v, opened %v, asked %d", ok, took, o.slots, a.asked)
	}
}

func TestUnlockOtherVolume(t *testing.T) {
	r := newRig(t, 512, mbr)
	c, out := r.creator()
	if err := c.create(r.dev("sda"), r.dev("nvme0n1p3"), false); err != nil {
		t.Fatalf("%v\n%s", err, out)
	}
	u, o, _ := r.unlocker()
	if u.run(300*time.Millisecond) || len(o.slots) != 0 {
		t.Fatalf("another volume's key was tried: %v", o.slots)
	}
}

func TestUnlockPluggedLater(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	r.unplug()
	go func() {
		time.Sleep(300 * time.Millisecond)
		r.plug()
	}()
	u, o, _ := r.unlocker()
	start := time.Now()
	if !u.run(5*time.Second) || len(o.slots) != 1 {
		t.Fatalf("not unlocked: %v", o.slots)
	}
	if took := time.Since(start); took < 300*time.Millisecond || took > 3*time.Second {
		t.Errorf("took %v", took)
	}
}

func TestUnlockAlreadyActive(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	r.f.dm(0, "other")
	r.f.dm(1, "enc")
	u, o, _ := r.unlocker()
	if !u.run(time.Second) || len(o.slots) != 0 {
		t.Fatalf("opened %v", o.slots)
	}
}

func TestUnlockLUKSLater(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	u, o, _ := r.unlocker()
	u.luks = r.dev("late")
	go func() {
		time.Sleep(300 * time.Millisecond)
		r.f.link("late", r.luks)
	}()
	if !u.run(5*time.Second) || len(o.slots) != 1 {
		t.Fatalf("the LUKS device showing up late: %v", o.slots)
	}
}

func TestUnlockKeyCleared(t *testing.T) {
	r := newRig(t, 512, mbr)
	r.mustCreate(false)
	var seen []byte
	u, _, _ := r.unlocker()
	u.open = func(s []byte, slot int) error { seen = s; return nil }
	if !u.run(time.Second) {
		t.Fatal("not unlocked")
	}
	if !allZero(seen) {
		t.Error("key left in memory after use")
	}
}
