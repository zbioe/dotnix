// dotnix-key: a LUKS key hidden in the gap of any USB stick.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"
)

// Set at build time to store paths (default.nix).
var (
	cryptsetupBin  = "cryptsetup"
	askPasswordBin = "systemd-ask-password"
)

const usage = `usage:
  dotnix-key list
  dotnix-key create [-pin | -pin-file FILE] [-luks DEVICE] [-yes] [-force] DISK
  dotnix-key adopt [-offset 2048] [-luks DEVICE] [-yes] DISK
  dotnix-key export [-luks DEVICE] DISK > KEY    the stick's key, to put back
  dotnix-key import [-pin-file FILE] [-luks DEVICE] [-yes] [-force] DISK < KEY
                                                 on it or another one
  dotnix-key unlock -device DEVICE -name NAME [-timeout 10s] [-allow-discards]
                    [-no-read-workqueue] [-no-write-workqueue] [-ask-password PATH]
`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	cmd, args := os.Args[1], os.Args[2:]
	var err error
	switch cmd {
	case "list":
		err = list(hostFS, os.Stdout)
	case "create", "adopt", "import":
		err = writeCmd(cmd, args)
	case "export":
		err = exportCmd(args)
	case "unlock":
		unlockCmd(args)
	default:
		fmt.Fprint(os.Stderr, usage)
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "dotnix-key:", err)
		os.Exit(1)
	}
}

// parse accepts flags before and after the positional arguments.
func parse(fs *flag.FlagSet, args []string) []string {
	fs.Usage = func() { fmt.Fprint(os.Stderr, usage) }
	fs.Parse(args)
	pos := []string{}
	for fs.NArg() > 0 {
		pos = append(pos, fs.Arg(0))
		fs.Parse(fs.Args()[1:])
	}
	return pos
}

func writeCmd(cmd string, args []string) error {
	fs := flag.NewFlagSet(cmd, flag.ExitOnError)
	pin := fs.Bool("pin", false, "the stick also needs a PIN")
	pinFile := fs.String("pin-file", "", "the PIN, read from a file (no prompt)")
	luks := fs.String("luks", "", "the LUKS volume (default: the only one)")
	yes := fs.Bool("yes", false, "don't ask")
	force := fs.Bool("force", false, "overwrite a gap holding other data")
	offset := fs.Int64("offset", 2048, "where the old key is (adopt)")
	pos := parse(fs, args)
	if len(pos) != 1 {
		fs.Usage()
		os.Exit(2)
	}
	ask := func(p string) (string, error) { return askPassword(askPasswordBin, p) }
	if *pinFile != "" {
		b, err := os.ReadFile(*pinFile)
		if err != nil {
			return err
		}
		pinText := strings.TrimSuffix(string(b), "\n")
		ask = func(string) (string, error) { return pinText, nil }
		*pin = true
	}
	c := &creator{
		fs:    hostFS,
		cs:    cryptsetup{bin: cryptsetupBin},
		ask:   ask,
		in:    bufio.NewReader(os.Stdin),
		out:   os.Stdout,
		yes:   *yes,
		force: *force,
	}
	switch cmd {
	case "adopt":
		return c.adopt(pos[0], *luks, *offset)
	case "import":
		return c.importKey(pos[0], *luks, os.Stdin)
	}
	return c.create(pos[0], *luks, *pin)
}

// exportCmd won't print the key on a terminal: to a pipe or a file only.
func exportCmd(args []string) error {
	fs := flag.NewFlagSet("export", flag.ExitOnError)
	luks := fs.String("luks", "", "the LUKS volume (default: the only one)")
	pos := parse(fs, args)
	if len(pos) != 1 {
		fs.Usage()
		os.Exit(2)
	}
	if st, err := os.Stdout.Stat(); err == nil && st.Mode()&os.ModeCharDevice != 0 {
		return errors.New("export prints the key itself: redirect it (> FILE or | dotnix-key import)")
	}
	c := &creator{fs: hostFS, cs: cryptsetup{bin: cryptsetupBin}, out: os.Stdout}
	return c.export(pos[0], *luks)
}

func unlockCmd(args []string) {
	fs := flag.NewFlagSet("unlock", flag.ExitOnError)
	device := fs.String("device", "", "the LUKS device")
	name := fs.String("name", "", "the /dev/mapper name")
	timeout := fs.Duration("timeout", 10*time.Second, "how long to wait for a stick")
	discards := fs.Bool("allow-discards", false, "")
	noRead := fs.Bool("no-read-workqueue", false, "")
	noWrite := fs.Bool("no-write-workqueue", false, "")
	ask := fs.String("ask-password", askPasswordBin, "")
	if pos := parse(fs, args); len(pos) != 0 || *device == "" || *name == "" {
		fs.Usage()
		os.Exit(2)
	}
	var flags []string
	if *discards {
		flags = append(flags, "--allow-discards")
	}
	if *noRead {
		flags = append(flags, "--perf-no_read_workqueue")
	}
	if *noWrite {
		flags = append(flags, "--perf-no_write_workqueue")
	}
	cs := cryptsetup{bin: cryptsetupBin}
	u := &unlocker{
		fs:   hostFS,
		luks: *device,
		name: *name,
		open: func(s []byte, slot int) error { return cs.open(*device, *name, s, slot, flags) },
		ask:  func(p string) (string, error) { return askPassword(*ask, p) },
		log:  os.Stderr,
		poll: 100 * time.Millisecond,
	}
	u.run(*timeout) // always exits 0: the passphrase is the fallback
}
