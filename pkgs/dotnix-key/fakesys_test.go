package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

// fakeSys mimics /sys/class/block and /dev in a temp dir; /dev nodes link to image files.
type fakeSys struct {
	t     *testing.T
	fs    sysfs
	minor int
}

func newFakeSys(t *testing.T) *fakeSys {
	root := t.TempDir()
	f := &fakeSys{t: t, fs: sysfs{sys: filepath.Join(root, "sys"), dev: filepath.Join(root, "dev")}}
	f.mkdir(filepath.Join(f.fs.sys, "class", "block"))
	f.mkdir(f.fs.dev)
	return f
}

func (f *fakeSys) mkdir(path string) {
	if err := os.MkdirAll(path, 0o755); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fakeSys) write(path, content string) {
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fakeSys) entry(real, name, uevent string, start, sectors uint64) {
	f.mkdir(real)
	f.minor++
	f.write(filepath.Join(real, "uevent"), fmt.Sprintf("MAJOR=8\nMINOR=%d\nDEVNAME=%s\n%s", f.minor, name, uevent))
	f.write(filepath.Join(real, "dev"), fmt.Sprintf("8:%d\n", f.minor))
	f.write(filepath.Join(real, "size"), strconv.FormatUint(sectors, 10)+"\n")
	if start > 0 {
		f.write(filepath.Join(real, "start"), strconv.FormatUint(start, 10)+"\n")
	}
	if err := os.Symlink(real, filepath.Join(f.fs.sys, "class", "block", name)); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fakeSys) diskDir(name string, usb bool) string {
	bus := "pci0000:00/0000:00:1d.0/nvme/nvme0"
	if usb {
		bus = "pci0000:00/0000:00:14.0/usb2/2-1/2-1:1.0/host6/target6:0:0/6:0:0:0"
	}
	return filepath.Join(f.fs.sys, "devices", bus, "block", name)
}

// disk adds a whole disk backed by image (if not empty) with the given logical sector size.
func (f *fakeSys) disk(name string, usb bool, image string, ss int) {
	dir := f.diskDir(name, usb)
	var sectors uint64
	if st, err := os.Stat(image); err == nil {
		sectors = uint64(st.Size()) / 512
	}
	f.entry(dir, name, "DEVTYPE=disk\n", 0, sectors)
	removable := "0"
	if usb {
		removable = "1"
	}
	f.write(filepath.Join(dir, "removable"), removable+"\n")
	f.mkdir(filepath.Join(dir, "queue"))
	f.write(filepath.Join(dir, "queue", "logical_block_size"), strconv.Itoa(ss)+"\n")
	if image != "" {
		f.link(name, image)
	}
}

// part adds a partition, start and size in 512-byte units as the kernel gives them.
func (f *fakeSys) part(disk string, usb bool, name string, start, sectors uint64, node string) {
	f.entry(filepath.Join(f.diskDir(disk, usb), name), name, "DEVTYPE=partition\n", start, sectors)
	if node != "" {
		f.link(name, node)
	}
}

func (f *fakeSys) link(name, target string) {
	if err := os.Symlink(target, filepath.Join(f.fs.dev, name)); err != nil {
		f.t.Fatal(err)
	}
}

func (f *fakeSys) dm(index int, name string) {
	dir := filepath.Join(f.fs.sys, "class", "block", fmt.Sprintf("dm-%d", index), "dm")
	f.mkdir(dir)
	f.write(filepath.Join(dir, "name"), name+"\n")
}
