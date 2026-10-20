package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

const pinTries = 3

// unlocker never fails the boot: without a key, systemd-cryptsetup asks the passphrase.
type unlocker struct {
	fs   sysfs
	luks string
	name string
	open func(secret []byte, slot int) error
	ask  func(prompt string) (string, error)
	log  io.Writer
	poll time.Duration
}

func (u *unlocker) logf(format string, args ...any) {
	fmt.Fprintf(u.log, "dotnix-key: "+format+"\n", args...)
}

func (u *unlocker) active() bool {
	names, _ := filepath.Glob(filepath.Join(u.fs.sys, "class", "block", "dm-*", "dm", "name"))
	for _, path := range names {
		if u.fs.read(path) == u.name {
			return true
		}
	}
	return false
}

// scan looks once at every disk not seen yet; a disk that can't be read yet is retried.
func (u *unlocker) scan(uuid string, seen map[string]bool) (found, blockDev, bool) {
	devs, err := u.fs.blockDevs()
	if err != nil {
		u.logf("listing block devices: %v", err)
		return found{}, blockDev{}, false
	}
	for _, d := range devs {
		id := d.DevNum + " " + d.Name
		if d.Partition || seen[id] || len(partsOf(devs, d.Name)) == 0 {
			continue
		}
		_, gap, err := u.fs.diskGap(d, devs)
		if err != nil && !errors.Is(err, errNoGap) {
			u.logf("%s: %v", d.Path, err)
			continue
		}
		seen[id] = true
		if err != nil {
			continue
		}
		if f, ok := find(gap, uuid); ok {
			return f, d, true
		}
	}
	return found{}, blockDev{}, false
}

// tryKey opens with a stick's key, asking its PIN; false falls back to the passphrase.
func (u *unlocker) tryKey(f found, d blockDev) bool {
	defer clear(f.Key)
	if !f.PIN {
		s := secret(f.Key, "")
		err := u.open(s, f.Slot)
		clear(s)
		if err != nil {
			u.logf("the key on %s does not open %s: %v", d.Path, u.luks, err)
			return false
		}
		return true
	}
	for i := range pinTries {
		pin, err := u.ask(fmt.Sprintf("PIN for %s (empty: passphrase):", u.name))
		if err != nil || pin == "" {
			return false
		}
		s := secret(f.Key, pin)
		err = u.open(s, f.Slot)
		clear(s)
		if err == nil {
			return true
		}
		u.logf("wrong PIN (%d of %d)", i+1, pinTries)
	}
	return false
}

func (u *unlocker) run(timeout time.Duration) bool {
	deadline := time.Now().Add(timeout)
	seen := map[string]bool{}
	uuid := ""
	for {
		if u.active() {
			u.logf("%s is open already", u.name)
			return true
		}
		if uuid == "" {
			if info, err := readLUKS(u.luks); err == nil {
				uuid = info.UUID
			} else if !errors.Is(err, os.ErrNotExist) {
				u.logf("%s: %v", u.luks, err)
			}
		}
		if uuid != "" {
			if f, d, ok := u.scan(uuid, seen); ok {
				if u.tryKey(f, d) {
					u.logf("%s opened with the key on %s", u.name, d.Path)
					return true
				}
				u.logf("asking the passphrase")
				return false
			}
		}
		if time.Now().After(deadline) {
			u.logf("no key for %s in %s, asking the passphrase", u.luks, timeout)
			return false
		}
		time.Sleep(u.poll)
	}
}
