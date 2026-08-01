// SPDX-License-Identifier: Apache-2.0

// Command ahb_trace_decode decodes an ahb_recorder (//ip/debug) UART dump into
// an annotated AHB trace, mapping each address onto the NOEL-V memory map.
// Non-matching lines (e.g. boot banners) are passed through unchanged, so it can
// run directly on a raw serial capture.
//
// Usage:
//
//	ahb_trace_decode [dump.txt]   # or pipe the serial capture on stdin
package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strconv"
)

// region is a named span of the address map.
type region struct {
	base, size uint64
	name       string
}

// regions of the NOEL-V address map (see boards/noelv/board.dts).
var regions = []region{
	{0x00000000, 0x40000000, "DDR3"},     // shared main RAM (OpenSBI @ +0x40000)
	{0xC0000000, 0x00100000, "BOOTBRAM"}, // NOEL-V boot ROM
	{0xE0000000, 0x00010000, "CLINT"},
	{0x80000300, 0x00000100, "GPTIMER"},
	{0xFF900000, 0x00001000, "APBUART"},
	{0x40000040, 0x00000004, "PERCONTROL"},
}

// annotate returns "REGION+0xoffset" for addr, or "?" if it is outside any region.
func annotate(addr uint64) string {
	for _, r := range regions {
		if addr >= r.base && addr < r.base+r.size {
			if off := addr - r.base; off != 0 {
				return fmt.Sprintf("%s+0x%x", r.name, off)
			}
			return r.name
		}
	}
	return "?"
}

// One captured record: "CCCCCCCC W AAAAAAAA DDDDDDDD".
var lineRE = regexp.MustCompile(`^([0-9a-fA-F]{8}) ([WR]) ([0-9a-fA-F]{8}) ([0-9a-fA-F]{8})\s*$`)

// decode reads dump lines from in and writes the annotated trace to out.
func decode(in *os.File, out *bufio.Writer) {
	sc := bufio.NewScanner(in)
	for sc.Scan() {
		line := sc.Text()
		m := lineRE.FindStringSubmatch(line)
		if m == nil {
			fmt.Fprintln(out, line) // pass banners / noise through
			continue
		}
		cyc, _ := strconv.ParseUint(m[1], 16, 64)
		addr, _ := strconv.ParseUint(m[3], 16, 64)
		op, extra := "RD", ""
		if m[2] == "W" {
			op, extra = "WR", " = 0x"+m[4]
		}
		fmt.Fprintf(out, "+%-10d %s  0x%s %-16s%s\n", cyc, op, m[3], annotate(addr), extra)
	}
}

func main() {
	in := os.Stdin
	if len(os.Args) > 1 {
		f, err := os.Open(os.Args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		defer f.Close()
		in = f
	}
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	decode(in, out)
}
