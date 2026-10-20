package main

import (
	"bufio"
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

var fastKDF = []string{"--pbkdf", "pbkdf2", "--pbkdf-force-iterations", "1000"}

// rig: an internal disk with LUKS (passphrase "pass") and a USB stick image as sda.
type rig struct {
	t     *testing.T
	f     *fakeSys
	luks  string
	other string
	stick string
	ss    int
	parts []blockDev
}

func newRig(t *testing.T, ss int, script string) *rig {
	t.Helper()
	r := &rig{t: t, f: newFakeSys(t), luks: luksFile(t, "luks2"), other: luksFile(t, "luks2"), ss: ss}
	r.f.disk("nvme0n1", false, emptyFile(t, 1<<20), 512)
	r.f.part("nvme0n1", false, "nvme0n1p2", 2048, 65536, r.luks)
	r.f.part("nvme0n1", false, "nvme0n1p3", 67584, 65536, r.other)
	r.stick, r.parts = image(t, 16<<20, ss, script)
	r.plug()
	return r
}

func (r *rig) plug() {
	r.f.disk("sda", true, r.stick, r.ss)
	for i, p := range r.parts {
		r.f.part("sda", true, "sda"+strconv.Itoa(i+1), p.Start, 2048, "")
	}
}

func (r *rig) unplug() {
	for _, name := range []string{"sda", "sda1", "sda2", "sda3", "sda4"} {
		os.Remove(filepath.Join(r.f.fs.sys, "class", "block", name))
		os.Remove(filepath.Join(r.f.fs.dev, name))
	}
	os.RemoveAll(r.f.diskDir("sda", true))
}

func (r *rig) dev(name string) string { return filepath.Join(r.f.fs.dev, name) }

type asker struct {
	mu      sync.Mutex
	answers []string
	asked   int
}

func (a *asker) ask(string) (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.asked++
	if len(a.answers) == 0 {
		return "", io.EOF
	}
	ans := a.answers[0]
	a.answers = a.answers[1:]
	return ans, nil
}

func (r *rig) creator(answers ...string) (*creator, *bytes.Buffer) {
	out := &bytes.Buffer{}
	return &creator{
		fs:  r.f.fs,
		cs:  cryptsetup{bin: "cryptsetup", stdin: strings.NewReader("pass"), kdf: fastKDF},
		ask: (&asker{answers: answers}).ask,
		in:  bufio.NewReader(strings.NewReader("")),
		out: out,
		yes: true,
	}, out
}

func (r *rig) mustCreate(pin bool, answers ...string) string {
	r.t.Helper()
	c, out := r.creator(answers...)
	if err := c.create(r.dev("sda"), r.dev("nvme0n1p2"), pin); err != nil {
		r.t.Fatalf("create: %v\n%s", err, out)
	}
	return out.String()
}

type opener struct {
	mu    sync.Mutex
	luks  string
	slots []int
}

func (o *opener) open(s []byte, slot int) error {
	o.mu.Lock()
	o.slots = append(o.slots, slot)
	o.mu.Unlock()
	return cryptsetup{bin: "cryptsetup"}.testKey(o.luks, s, slot)
}

func (r *rig) unlocker(answers ...string) (*unlocker, *opener, *asker) {
	o := &opener{luks: r.luks}
	a := &asker{answers: answers}
	return &unlocker{
		fs: r.f.fs, luks: r.dev("nvme0n1p2"), name: "enc",
		open: o.open, ask: a.ask, log: io.Discard, poll: 20 * time.Millisecond,
	}, o, a
}

func (r *rig) used() map[int]bool {
	r.t.Helper()
	info, err := readLUKS(r.luks)
	if err != nil {
		r.t.Fatal(err)
	}
	return info.Used
}

func (r *rig) wantSlots(want ...int) {
	r.t.Helper()
	used := r.used()
	if len(used) != len(want) {
		r.t.Fatalf("slots in use %v, want %v", used, want)
	}
	for _, s := range want {
		if !used[s] {
			r.t.Fatalf("slots in use %v, want %v", used, want)
		}
	}
}

func (r *rig) gap() (gapRange, []byte) {
	r.t.Helper()
	devs, _ := r.f.fs.blockDevs()
	d, _ := findDev(devs, r.dev("sda"))
	g, buf, err := r.f.fs.diskGap(d, devs)
	if err != nil {
		r.t.Fatal(err)
	}
	return g, buf
}

func (r *rig) read() []byte {
	b, err := os.ReadFile(r.stick)
	if err != nil {
		r.t.Fatal(err)
	}
	return b
}

// sameOutsideGap checks that nothing but the gap changed.
func (r *rig) sameOutsideGap(before []byte) {
	r.t.Helper()
	after := r.read()
	g, _ := r.gap()
	if !bytes.Equal(before[:g.Start], after[:g.Start]) || !bytes.Equal(before[g.End:], after[g.End:]) {
		r.t.Fatal("bytes outside the gap changed")
	}
}
