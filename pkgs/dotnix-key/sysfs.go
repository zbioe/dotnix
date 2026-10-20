package main

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Block devices read from /sys, so no udev is needed (initrd).
type blockDev struct {
	Name      string
	Path      string
	Disk      string // itself for a whole disk
	Partition bool
	DevNum    string // major:minor
	Start     uint64 // 512-byte units, partitions only
	Sectors   uint64 // 512-byte units
	USB       bool
	Removable bool
}

type sysfs struct {
	sys string
	dev string
}

var hostFS = sysfs{sys: "/sys", dev: "/dev"}

func (s sysfs) read(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readUevent(path string) map[string]string {
	vars := map[string]string{}
	f, err := os.Open(path)
	if err != nil {
		return vars
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if k, v, ok := strings.Cut(sc.Text(), "="); ok {
			vars[k] = v
		}
	}
	return vars
}

func (s sysfs) blockDevs() ([]blockDev, error) {
	class := filepath.Join(s.sys, "class", "block")
	entries, err := os.ReadDir(class)
	if err != nil {
		return nil, err
	}
	var devs []blockDev
	for _, e := range entries {
		dir := filepath.Join(class, e.Name())
		real, err := filepath.EvalSymlinks(dir)
		if err != nil {
			continue
		}
		ev := readUevent(filepath.Join(dir, "uevent"))
		devName := ev["DEVNAME"]
		if devName == "" {
			devName = e.Name()
		}
		d := blockDev{
			Name:      e.Name(),
			Path:      filepath.Join(s.dev, devName),
			Disk:      e.Name(),
			Partition: ev["DEVTYPE"] == "partition",
			DevNum:    s.read(filepath.Join(dir, "dev")),
		}
		if d.Partition {
			d.Disk = filepath.Base(filepath.Dir(real))
		}
		d.Sectors, _ = strconv.ParseUint(s.read(filepath.Join(dir, "size")), 10, 64)
		d.Start, _ = strconv.ParseUint(s.read(filepath.Join(dir, "start")), 10, 64)
		d.Removable = s.read(filepath.Join(class, d.Disk, "removable")) == "1"
		for _, part := range strings.Split(real, string(filepath.Separator)) {
			if strings.HasPrefix(part, "usb") {
				d.USB = true
			}
		}
		devs = append(devs, d)
	}
	sort.Slice(devs, func(i, j int) bool { return devs[i].Name < devs[j].Name })
	return devs, nil
}

func partsOf(devs []blockDev, disk string) []blockDev {
	var parts []blockDev
	for _, d := range devs {
		if d.Partition && d.Disk == disk {
			parts = append(parts, d)
		}
	}
	return parts
}

func (s sysfs) logicalSectorSize(disk string) uint64 {
	n, err := strconv.ParseUint(s.read(filepath.Join(s.sys, "class", "block", disk, "queue", "logical_block_size")), 10, 64)
	if err != nil || n == 0 {
		return 512
	}
	return n
}

// mounted matches by device number, so names and symlinks don't matter.
func mounted(devs []blockDev) (string, bool) {
	f, err := os.Open("/proc/self/mountinfo")
	if err != nil {
		return "", false
	}
	defer f.Close()
	nums := map[string]string{}
	for _, d := range devs {
		nums[d.DevNum] = d.Path
	}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) > 2 {
			if path, ok := nums[fields[2]]; ok {
				return path, true
			}
		}
	}
	return "", false
}
