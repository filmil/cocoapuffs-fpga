// SPDX-License-Identifier: Apache-2.0
// bintoinc creates byte definitions for inclusion into assembly source.
package main

import (
	"bufio"
	"flag"
	"io"
	"log"
	"os"
)

const NumBits = 32
const NumEntries = 10

const WordInBytes = NumBits / 8

const hexTable = "0123456789abcdef"

var hexTable256 [256][2]byte

func init() {
	for i := 0; i < 256; i++ {
		hexTable256[i][0] = hexTable[i>>4]
		hexTable256[i][1] = hexTable[i&0x0f]
	}
}

// Convert converts a binary file into a set of bytes suitable for inclusion
// into Verilog source
func Convert(w io.Writer, r io.Reader, byteCount int) error {
	bw := bufio.NewWriter(w)
	// Use a larger buffer for reading to reduce system calls.
	// 4096 is a common page size and a multiple of WordInBytes (4).
	b := make([]byte, 4096)
	// lineBuf is used to construct each line before writing to bw.
	// A line consists of WordInBytes hex pairs and WordInBytes-1 spaces, plus a newline.
	// For WordInBytes=4, this is 4*2 + 3 + 1 = 12 bytes.
	lineBuf := make([]byte, WordInBytes*3)

	for {
		n, err := r.Read(b)
		if n > 0 {
			byteCount -= n
			for i := 0; i < n; i += WordInBytes {
				chunkSize := WordInBytes
				if i+chunkSize > n {
					chunkSize = n - i
				}

				lineIdx := 0
				for j := 0; j < chunkSize; j++ {
					val := b[i+j]
					hex := hexTable256[val]
					lineBuf[lineIdx] = hex[0]
					lineBuf[lineIdx+1] = hex[1]
					lineIdx += 2
					if j < chunkSize-1 {
						lineBuf[lineIdx] = ' '
						lineIdx++
					}
				}
				lineBuf[lineIdx] = '\n'
				lineIdx++
				bw.Write(lineBuf[:lineIdx])
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
	}
	padding := []byte("00\n")
	for byteCount > 0 {
		byteCount--
		bw.Write(padding)
	}
	return bw.Flush()
}

func main() {
	var byteCount int
	log.SetPrefix(os.Args[0])
	flag.IntVar(&byteCount, "fill-to-bytes", 0, "If there aren't enough bytes, fill to this value with zeros")
	flag.Parse()

	if err := Convert(os.Stdout, os.Stdin, byteCount); err != nil {
		log.Fatalf("error during conversion: %v", err)
	}
}
