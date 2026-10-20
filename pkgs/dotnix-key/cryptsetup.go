package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type cryptsetup struct {
	bin   string
	stdin io.Reader // nil: the terminal, for passphrase prompts
	kdf   []string  // extra luksAddKey options (tests use a fast KDF)
}

// run passes each secret through a pipe as /dev/fd/3, /dev/fd/4, ...
func (c cryptsetup) run(secrets [][]byte, args ...string) error {
	cmd := exec.Command(c.bin, args...)
	cmd.Stdin = c.stdin
	if cmd.Stdin == nil {
		cmd.Stdin = os.Stdin
	}
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	for _, s := range secrets {
		r, w, err := os.Pipe()
		if err != nil {
			return err
		}
		_, err = w.Write(s) // smaller than the pipe buffer: never blocks
		w.Close()
		if err != nil {
			r.Close()
			return err
		}
		defer r.Close()
		cmd.ExtraFiles = append(cmd.ExtraFiles, r)
	}
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("cryptsetup %s: %w", strings.Join(args, " "), err)
	}
	return nil
}

func size(b []byte) string { return strconv.Itoa(len(b)) }

// addKey asks an existing passphrase on the terminal.
func (c cryptsetup) addKey(luks string, secret []byte, slot int) error {
	args := append([]string{"luksAddKey", "--batch-mode",
		"--new-key-slot", strconv.Itoa(slot), "--new-keyfile-size", size(secret)}, c.kdf...)
	return c.run([][]byte{secret}, append(args, luks, "/dev/fd/3")...)
}

func (c cryptsetup) testKey(luks string, secret []byte, slot int) error {
	return c.run([][]byte{secret}, "open", "--test-passphrase", "--batch-mode",
		"--key-file", "/dev/fd/3", "--keyfile-size", size(secret),
		"--key-slot", strconv.Itoa(slot), luks)
}

// open reads the secret from stdin: the initrd may have no /dev/fd.
func (c cryptsetup) open(luks, name string, secret []byte, slot int, flags []string) error {
	args := []string{"open", "--batch-mode", "--key-file", "-", "--keyfile-size", size(secret),
		"--key-slot", strconv.Itoa(slot)}
	args = append(append(args, flags...), luks, name)
	return cryptsetup{bin: c.bin, stdin: bytes.NewReader(secret)}.run(nil, args...)
}

// killSlot is authorized by a key of another slot; nil (the slot's own key is refused) skips the check.
func (c cryptsetup) killSlot(luks string, slot int, auth []byte) error {
	if auth == nil {
		return cryptsetup{bin: c.bin, stdin: strings.NewReader("")}.run(nil, "luksKillSlot", "--batch-mode", luks, strconv.Itoa(slot))
	}
	return c.run([][]byte{auth}, "luksKillSlot", "--batch-mode",
		"--key-file", "/dev/fd/3", "--keyfile-size", size(auth), luks, strconv.Itoa(slot))
}

// askPassword runs systemd-ask-password: plymouth, the console agent or the terminal.
func askPassword(bin, prompt string) (string, error) {
	cmd := exec.Command(bin, "--timeout=120", "--id=dotnix-key", prompt)
	cmd.Stdin = os.Stdin
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSuffix(string(out), "\n"), nil
}
