package main

import (
	"bytes"
	"io"
	"testing"
)

func BenchmarkConvert(b *testing.B) {
	// Create a dummy payload of 1MB
	payload := make([]byte, 1024*1024)
	for i := range payload {
		payload[i] = byte(i)
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		reader := bytes.NewReader(payload)
		err := Convert(io.Discard, reader, 1024*1024)
		if err != nil {
			b.Fatal(err)
		}
	}
}

func TestConvertOutput(t *testing.T) {
	input := []byte{0x00, 0x01, 0x0a, 0xff}
	reader := bytes.NewReader(input)
	var output bytes.Buffer

	err := Convert(&output, reader, 0)
	if err != nil {
		t.Fatal(err)
	}

	expected := "00 01 0a ff\n"
	if output.String() != expected {
		t.Errorf("expected %q, got %q", expected, output.String())
	}
}

func TestConvertOutputWithPadding(t *testing.T) {
	input := []byte{0x00, 0x01, 0x0a, 0xff}
	reader := bytes.NewReader(input)
	var output bytes.Buffer

	err := Convert(&output, reader, 6)
	if err != nil {
		t.Fatal(err)
	}

	expected := "00 01 0a ff\n00\n00\n"
	if output.String() != expected {
		t.Errorf("expected %q, got %q", expected, output.String())
	}
}

func TestConvertOutputPartialWord(t *testing.T) {
	input := []byte{0x00, 0x01}
	reader := bytes.NewReader(input)
	var output bytes.Buffer

	err := Convert(&output, reader, 0)
	if err != nil {
		t.Fatal(err)
	}

	expected := "00 01\n"
	if output.String() != expected {
		t.Errorf("expected %q, got %q", expected, output.String())
	}
}
