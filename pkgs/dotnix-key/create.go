package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
	"math/big"
	"os"
	"sort"
	"strings"
)

const minPIN = 4

type creator struct {
	fs    sysfs
	cs    cryptsetup
	ask   func(prompt string) (string, error)
	in    *bufio.Reader
	out   io.Writer
	yes   bool
	force bool
}

// target is a stick being written and the LUKS volume its key is for.
type target struct {
	disk blockDev
	luks blockDev
	info luksInfo
	gap  gapRange
	cur  []byte
}

func (c *creator) printf(format string, args ...any) { fmt.Fprintf(c.out, format, args...) }

func (c *creator) confirm(t target, what string) error {
	note := "not USB!"
	if t.disk.USB {
		note = "USB"
	}
	c.printf("%s  %s  (%s), gap %s at %d\n", t.disk.Path, humanSize(t.disk.Sectors*512), note, humanSize(uint64(t.gap.size())), t.gap.Start)
	c.printf("%s\n", what)
	if c.yes {
		return nil
	}
	c.printf("Type YES to continue: ")
	line, _ := c.in.ReadString('\n')
	if strings.TrimSpace(line) != "YES" {
		return errors.New("aborted")
	}
	return nil
}

func humanSize(n uint64) string {
	switch {
	case n >= 1<<30:
		return fmt.Sprintf("%.1fG", float64(n)/(1<<30))
	case n >= 1<<20:
		return fmt.Sprintf("%.1fM", float64(n)/(1<<20))
	default:
		return fmt.Sprintf("%dK", n>>10)
	}
}

// findDev matches by file identity, so /dev/disk/by-id links work too.
func findDev(devs []blockDev, path string) (blockDev, error) {
	want, err := os.Stat(path)
	if err != nil {
		return blockDev{}, err
	}
	for _, d := range devs {
		if st, err := os.Stat(d.Path); err == nil && os.SameFile(st, want) {
			return d, nil
		}
	}
	return blockDev{}, fmt.Errorf("%s is not a block device", path)
}

// findLUKS: the given volume, or the only one there is.
func findLUKS(devs []blockDev, path string) (blockDev, luksInfo, error) {
	if path != "" {
		d, err := findDev(devs, path)
		if err != nil {
			return blockDev{}, luksInfo{}, err
		}
		info, err := readLUKS(d.Path)
		return d, info, err
	}
	var found []blockDev
	var infos []luksInfo
	for _, d := range devs {
		if info, err := readLUKS(d.Path); err == nil {
			found = append(found, d)
			infos = append(infos, info)
		}
	}
	if len(found) != 1 {
		var paths []string
		for _, d := range found {
			paths = append(paths, d.Path)
		}
		return blockDev{}, luksInfo{}, fmt.Errorf("%d LUKS volumes (%s): pick one with -luks", len(found), strings.Join(paths, " "))
	}
	return found[0], infos[0], nil
}

func (c *creator) prepare(device, luksPath string) (target, error) {
	devs, err := c.fs.blockDevs()
	if err != nil {
		return target{}, err
	}
	disk, err := findDev(devs, device)
	if err != nil {
		return target{}, err
	}
	if disk.Partition {
		return target{}, fmt.Errorf("%s is a partition: give the whole disk (/dev/%s)", device, disk.Disk)
	}
	luks, info, err := findLUKS(devs, luksPath)
	if err != nil {
		return target{}, err
	}
	if luks.Disk == disk.Name {
		return target{}, fmt.Errorf("%s holds the encrypted volume itself (%s)", disk.Path, luks.Path)
	}
	g, cur, err := c.fs.diskGap(disk, devs)
	if err != nil {
		return target{}, fmt.Errorf("%s: %w", disk.Path, err)
	}
	return target{disk: disk, luks: luks, info: info, gap: g, cur: cur}, nil
}

// checkGap refuses to overwrite what isn't ours (GRUB BIOS and Ventoy live there).
func (c *creator) checkGap(t target) (found, bool, error) {
	old, ok := find(t.cur, t.info.UUID)
	if !ok && !allZero(t.cur) && !c.force {
		return found{}, false, fmt.Errorf("the gap of %s holds data that is not a key for %s (a boot loader?): -force overwrites it", t.disk.Path, t.luks.Path)
	}
	return old, ok, nil
}

// write fills the gap with noise and puts key and tag at a random step.
func (c *creator) write(t target, key []byte, slot int, pin bool) error {
	buf := make([]byte, t.gap.size())
	if _, err := rand.Read(buf); err != nil {
		return err
	}
	n, err := rand.Int(rand.Reader, big.NewInt(int64((len(buf)-blockSize)/step+1)))
	if err != nil {
		return err
	}
	pos := int(n.Int64()) * step
	copy(buf[pos:], key)
	copy(buf[pos+keySize:], tag(key, t.info.UUID, slot, pin))

	f, err := os.OpenFile(t.disk.Path, os.O_WRONLY|os.O_SYNC, 0)
	if err != nil {
		return err
	}
	if _, err := f.WriteAt(buf, t.gap.Start); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	devs, err := c.fs.blockDevs()
	if err != nil {
		return err
	}
	_, got, err := c.fs.diskGap(t.disk, devs)
	if err != nil {
		return fmt.Errorf("read back: %w", err)
	}
	if !bytes.Equal(got, buf) {
		return fmt.Errorf("read back from %s differs from what was written", t.disk.Path)
	}
	return nil
}

func (c *creator) newPIN() (string, error) {
	pin, err := c.ask("PIN for this stick:")
	if err != nil {
		return "", err
	}
	if len(pin) < minPIN {
		return "", fmt.Errorf("a PIN needs at least %d characters", minPIN)
	}
	again, err := c.ask("The PIN again:")
	if err != nil {
		return "", err
	}
	if again != pin {
		return "", errors.New("the PINs differ")
	}
	return pin, nil
}

// verify reads the stick back the way the boot does and opens the slot with it.
func (c *creator) verify(t target, slot int, pin bool, pinStr string) error {
	devs, err := c.fs.blockDevs()
	if err != nil {
		return err
	}
	_, gap, err := c.fs.diskGap(t.disk, devs)
	if err != nil {
		return err
	}
	f, ok := find(gap, t.info.UUID)
	if !ok || f.Slot != slot || f.PIN != pin {
		return fmt.Errorf("the key on %s is not found as written", t.disk.Path)
	}
	return c.cs.testKey(t.luks.Path, secret(f.Key, pinStr), slot)
}

func (c *creator) create(device, luksPath string, withPIN bool) error {
	t, err := c.prepare(device, luksPath)
	if err != nil {
		return err
	}
	old, hasOld, err := c.checkGap(t)
	if err != nil {
		return err
	}
	what := "Its gap gets a new key; partitions and files are not touched."
	if hasOld {
		what = fmt.Sprintf("Its key (slot %d) is replaced by a new one; partitions and files are not touched.", old.Slot)
	}
	if err := c.confirm(t, what); err != nil {
		return err
	}
	pinStr := ""
	if withPIN {
		if pinStr, err = c.newPIN(); err != nil {
			return err
		}
	}
	slot, err := t.info.freeSlot()
	if err != nil {
		return err
	}
	key := make([]byte, keySize)
	if _, err := rand.Read(key); err != nil {
		return err
	}
	defer clear(key)

	c.printf("Adding the key in slot %d of %s (asks an existing passphrase)...\n", slot, t.luks.Path)
	if err := c.cs.addKey(t.luks.Path, secret(key, pinStr), slot); err != nil {
		return err
	}
	if err := c.write(t, key, slot, withPIN); err != nil {
		c.takeBack(t, slot)
		c.restore(t)
		return err
	}
	if err := c.verify(t, slot, withPIN, pinStr); err != nil {
		return fmt.Errorf("%s does not open %s: %w", t.disk.Path, t.luks.Path, err)
	}
	c.printf("%s opens %s (slot %d%s).\n", t.disk.Path, t.luks.Path, slot, pinNote(withPIN))
	if hasOld && old.Slot != slot {
		c.revoke(t, old, secret(key, pinStr))
	}
	return nil
}

func pinNote(pin bool) string {
	if pin {
		return ", with PIN"
	}
	return ""
}

// takeBack removes a slot whose key never reached the stick.
func (c *creator) takeBack(t target, slot int) {
	if err := c.cs.killSlot(t.luks.Path, slot, nil); err != nil {
		c.printf("warning: slot %d of %s holds a key nobody has: %v\n", slot, t.luks.Path, err)
	}
}

// restore puts the gap back as it was (the old key with it).
func (c *creator) restore(t target) {
	f, err := os.OpenFile(t.disk.Path, os.O_WRONLY|os.O_SYNC, 0)
	if err == nil {
		_, err = f.WriteAt(t.cur, t.gap.Start)
		if cerr := f.Close(); err == nil {
			err = cerr
		}
	}
	if err != nil {
		c.printf("warning: the gap of %s could not be restored: %v\n", t.disk.Path, err)
	}
}

// revoke removes the stick's previous slot, once its key is shown to open it.
func (c *creator) revoke(t target, old found, auth []byte) {
	pin := ""
	if old.PIN {
		var err error
		pin, err = c.ask(fmt.Sprintf("PIN of this stick's previous key (empty: keep slot %d):", old.Slot))
		if err != nil || pin == "" {
			c.printf("Slot %d (the previous key) is kept.\n", old.Slot)
			return
		}
	}
	if err := c.cs.testKey(t.luks.Path, secret(old.Key, pin), old.Slot); err != nil {
		c.printf("warning: the previous key does not open slot %d, so the slot is kept\n", old.Slot)
		return
	}
	if err := c.cs.killSlot(t.luks.Path, old.Slot, auth); err != nil {
		c.printf("warning: slot %d (the previous key) is still valid: %v\n", old.Slot, err)
		return
	}
	c.printf("Revoked slot %d, this stick's previous key.\n", old.Slot)
}

// adopt rewrites a key from a raw offset (the old way) in the gap format; LUKS is not changed.
func (c *creator) adopt(device, luksPath string, offset int64) error {
	t, err := c.prepare(device, luksPath)
	if err != nil {
		return err
	}
	if offset < t.gap.Start || offset+keySize > t.gap.End {
		return fmt.Errorf("offset %d is outside the gap of %s (%d to %d)", offset, t.disk.Path, t.gap.Start, t.gap.End)
	}
	if _, ok := find(t.cur, t.info.UUID); ok {
		return fmt.Errorf("%s already holds a key in the new format", t.disk.Path)
	}
	key := append([]byte{}, t.cur[offset-t.gap.Start:offset-t.gap.Start+keySize]...)
	defer clear(key)
	if allZero(key) {
		return fmt.Errorf("no key at offset %d of %s", offset, t.disk.Path)
	}
	var slots []int
	for s := range t.info.Used {
		slots = append(slots, s)
	}
	sort.Ints(slots)
	slot := -1
	for _, s := range slots {
		c.printf("Trying slot %d...\n", s)
		if c.cs.testKey(t.luks.Path, key, s) == nil {
			slot = s
			break
		}
	}
	if slot < 0 {
		return fmt.Errorf("the key at offset %d does not open %s", offset, t.luks.Path)
	}
	if err := c.confirm(t, fmt.Sprintf("The key at offset %d (slot %d) moves to a random place in the gap, the rest of it random; LUKS is not changed.", offset, slot)); err != nil {
		return err
	}
	if err := c.write(t, key, slot, false); err != nil {
		c.restore(t)
		return err
	}
	if err := c.verify(t, slot, false, ""); err != nil {
		c.restore(t)
		return err
	}
	c.printf("%s opens %s (slot %d), same key as before.\n", t.disk.Path, t.luks.Path, slot)
	return nil
}
