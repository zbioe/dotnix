package main

import (
	"fmt"
	"io"
)

func list(fs sysfs, out io.Writer) error {
	devs, err := fs.blockDevs()
	if err != nil {
		return err
	}
	volumes := map[string]string{}
	for _, d := range devs {
		if info, err := readLUKS(d.Path); err == nil {
			volumes[info.UUID] = d.Path
		}
	}
	matched := false
	for _, d := range devs {
		if d.Partition {
			continue
		}
		_, gap, err := fs.diskGap(d, devs)
		if err != nil {
			continue
		}
		for uuid, luks := range volumes {
			if f, ok := find(gap, uuid); ok {
				matched = true
				fmt.Fprintf(out, "%-12s opens %s (slot %d%s)\n", d.Path, luks, f.Slot, pinNote(f.PIN))
				clear(f.Key)
			}
		}
	}
	if !matched {
		fmt.Fprintln(out, "no stick with a key for this machine")
	}
	return nil
}
