package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestPathTraversal(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "prog_daemon_test")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	runtimeDir := filepath.Join(tmpDir, "runtime")
	if err := os.Mkdir(runtimeDir, 0755); err != nil {
		t.Fatalf("failed to create runtime dir: %v", err)
	}

	secretFile := filepath.Join(tmpDir, "secret.json")
	secretContent := `{"pid": 1234, "started_time": "2023-01-01T00:00:00Z"}`
	if err := os.WriteFile(secretFile, []byte(secretContent), 0644); err != nil {
		t.Fatalf("failed to create secret file: %v", err)
	}

	// We want to see if we can read secret.json by using path traversal in runFileName
	args := Args{
		runtimeDir:  runtimeDir,
		runFileName: "../secret.json",
		daemonLifetime: 100 * 365 * 24 * time.Hour, // very long lifetime
	}

	// The fix uses filepath.Base(args.runFileName)
	runFile := filepath.Join(args.runtimeDir, filepath.Base(args.runFileName))

	expectedPath := filepath.Join(runtimeDir, "secret.json")
	actualPath, _ := filepath.Abs(runFile)
	expectedAbsPath, _ := filepath.Abs(expectedPath)

	if actualPath != expectedAbsPath {
		t.Errorf("Expected path %s, but got %s", expectedAbsPath, actualPath)
	}

	// Verify it's inside runtimeDir
	rel, err := filepath.Rel(runtimeDir, actualPath)
	if err != nil {
		t.Errorf("Could not get relative path: %v", err)
	}
	if filepath.IsAbs(rel) || (len(rel) >= 2 && rel[:2] == "..") {
		t.Errorf("Path %s escaped runtimeDir %s", actualPath, runtimeDir)
	}
}

func TestReadRunFile(t *testing.T) {
	tmpDir := t.TempDir()
	runFile := filepath.Join(tmpDir, "test_run.json")

	now := time.Now().Truncate(time.Second)
	content := DaemonConfig{
		Pid:     1234,
		Started: now,
	}

	if err := writeRunFile(runFile, content); err != nil {
		t.Fatalf("writeRunFile failed: %v", err)
	}

	// Test success case
	got, err := readRunFile(runFile)
	if err != nil {
		t.Fatalf("readRunFile failed: %v", err)
	}

	if got.Pid != content.Pid {
		t.Errorf("got Pid %d, want %d", got.Pid, content.Pid)
	}

	if !got.Started.Equal(content.Started) {
		t.Errorf("got Started %v, want %v", got.Started, content.Started)
	}

	// Test failure case (file does not exist)
	if _, err := readRunFile("nonexistent.json"); err == nil {
		t.Error("readRunFile should have failed for nonexistent file")
	}

	// Test failure case (malformed JSON)
	malformedFile := filepath.Join(tmpDir, "malformed.json")
	if err := os.WriteFile(malformedFile, []byte("not json"), 0644); err != nil {
		t.Fatalf("os.WriteFile failed: %v", err)
	}
	if _, err := readRunFile(malformedFile); err == nil {
		t.Error("readRunFile should have failed for malformed JSON")
	}
}
