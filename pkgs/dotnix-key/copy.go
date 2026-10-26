package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"strconv"
	"strings"
)

// record is a stick's key outside it, as one line: what export prints and
// import reads. It opens the disk as the stick does.
type record struct {
	UUID string
	Slot int
	PIN  bool
	Key  []byte
}

const recordMagic = "dotnix-key-v1"

func (r record) String() string {
	pin := 0
	if r.PIN {
		pin = 1
	}
	return fmt.Sprintf("%s %s %d %d %s", recordMagic, r.UUID, r.Slot, pin, base64.StdEncoding.EncodeToString(r.Key))
}

func parseRecord(in io.Reader) (record, error) {
	line, err := bufio.NewReader(in).ReadString('\n')
	if err != nil && !errors.Is(err, io.EOF) {
		return record{}, err
	}
	f := strings.Fields(line)
	if len(f) != 5 || f[0] != recordMagic {
		return record{}, errors.New("not a key from dotnix-key export")
	}
	slot, err := strconv.Atoi(f[2])
	if err != nil || slot < 0 || slot >= maxSlots {
		return record{}, fmt.Errorf("slot %q", f[2])
	}
	key, err := base64.StdEncoding.DecodeString(f[4])
	if err != nil || len(key) != keySize {
		return record{}, errors.New("the key is damaged")
	}
	return record{UUID: f[1], Slot: slot, PIN: f[3] == "1", Key: key}, nil
}

// export prints the key the stick holds for the LUKS volume.
func (c *creator) export(device, luksPath string) error {
	t, err := c.prepare(device, luksPath)
	if err != nil {
		return err
	}
	defer t.unlock()
	f, ok := find(t.cur, t.info.UUID)
	if !ok {
		return fmt.Errorf("%s holds no key for %s", t.disk.Path, t.luks.Path)
	}
	defer clear(f.Key)
	_, err = fmt.Fprintln(c.out, record{UUID: t.info.UUID, Slot: f.Slot, PIN: f.PIN, Key: f.Key})
	return err
}

// importKey writes an exported key to a stick's gap; LUKS is not changed.
func (c *creator) importKey(device, luksPath string, in io.Reader) error {
	rec, err := parseRecord(in)
	if err != nil {
		return err
	}
	defer clear(rec.Key)
	t, err := c.prepare(device, luksPath)
	if err != nil {
		return err
	}
	defer t.unlock()
	if rec.UUID != t.info.UUID {
		return fmt.Errorf("the key is for the volume %s, not %s (%s)", rec.UUID, t.luks.Path, t.info.UUID)
	}
	old, hasOld, err := c.checkGap(t)
	if err != nil {
		return err
	}
	if hasOld && old.Slot == rec.Slot && bytes.Equal(old.Key, rec.Key) {
		c.printf("%s already holds this key (slot %d).\n", t.disk.Path, rec.Slot)
		return nil
	}
	what := fmt.Sprintf("Its gap gets the key of slot %d; partitions, files and LUKS are not touched.", rec.Slot)
	if hasOld {
		what += fmt.Sprintf(" The key it holds now (slot %d) is overwritten, its slot kept.", old.Slot)
	}
	if err := c.confirm(t, what); err != nil {
		return err
	}
	pin := ""
	if rec.PIN {
		if pin, err = c.ask("PIN of this key:"); err != nil {
			return err
		}
	}
	if err := c.cs.testKey(t.luks.Path, secret(rec.Key, pin), rec.Slot); err != nil {
		return fmt.Errorf("the key does not open slot %d of %s: %w", rec.Slot, t.luks.Path, err)
	}
	if err := c.write(t, rec.Key, rec.Slot, rec.PIN); err != nil {
		c.restore(t)
		return err
	}
	if err := c.verify(t, rec.Slot, rec.PIN, pin); err != nil {
		c.restore(t)
		return err
	}
	c.printf("%s opens %s (slot %d%s), the same key.\n", t.disk.Path, t.luks.Path, rec.Slot, pinNote(rec.PIN))
	if hasOld && old.Slot != rec.Slot {
		c.printf("Slot %d (the key it held) still opens %s: cryptsetup luksKillSlot %s %d, unless another stick has it.\n", old.Slot, t.luks.Path, t.luks.Path, old.Slot)
	}
	return nil
}
