package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func need(t *testing.T, tools ...string) {
	t.Helper()
	for _, tool := range tools {
		if _, err := exec.LookPath(tool); err != nil {
			t.Skipf("%s not in PATH", tool)
		}
	}
}

func sh(t *testing.T, stdin string, name string, args ...string) string {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Stdin = strings.NewReader(stdin)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %s: %v\n%s", name, strings.Join(args, " "), err, out)
	}
	return strings.TrimSpace(string(out))
}

func emptyFile(t *testing.T, size int64) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "disk.img")
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := f.Truncate(size); err != nil {
		t.Fatal(err)
	}
	f.Close()
	return path
}

// luksFile formats a file as LUKS (fast KDF) with passphrase "pass".
func luksFile(t *testing.T, version string) string {
	t.Helper()
	need(t, "cryptsetup")
	path := emptyFile(t, 32<<20)
	args := []string{"-q", "luksFormat", "--type", version, "--key-file", "-"}
	if version == "luks2" {
		args = append(args, "--pbkdf", "pbkdf2")
	}
	args = append(args, "--pbkdf-force-iterations", "1000", path)
	sh(t, "pass", "cryptsetup", args...)
	return path
}
