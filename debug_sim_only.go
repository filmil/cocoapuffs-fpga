// SPDX-License-Identifier: Apache-2.0
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

func main() {
	file, err := os.Open("bazel-bin/boards/noelv/tool.vivado/sim_only.vcd")
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var currentTime int64 = 0

	// Current states
	var rstn string = "0"
	var htrans string = "0"
	var haddr string = "0"
	var hrdata string = "0"
	var ahbReq string = "0"
	var wbCyc string = "0"
	var bramCyc string = "0"
	var txd string = "1"

	for scanner.Scan() {
		line := scanner.Text()
		if len(line) == 0 {
			continue
		}

		if line[0] == '#' {
			// Timestamp update
			var t int64
			_, err := fmt.Sscanf(line, "#%d", &t)
			if err == nil {
				currentTime = t
			}
			continue
		}

		// Check for single bit value changes
		if (line[0] == '0' || line[0] == '1' || line[0] == 'x' || line[0] == 'z' || line[0] == 'U' || line[0] == 'X') && len(line) > 1 {
			val := string(line[0])
			id := line[1:]
			changed := true
			switch id {
			case `"`:
				rstn = val
			case `;3`:
				ahbReq = val
			case `D3`:
				wbCyc = val
			case `M3`:
				bramCyc = val
			case `%`:
				txd = val
			default:
				changed = false
			}
			if changed {
				printState(currentTime, rstn, htrans, haddr, hrdata, ahbReq, wbCyc, bramCyc, txd)
			}
			continue
		}

		// Check for vector value changes
		if line[0] == 'b' {
			parts := strings.Split(line[1:], " ")
			if len(parts) == 2 {
				val := parts[0]
				id := parts[1]
				changed := true
				switch id {
				case `'/`:
					htrans = val
				case `(/`:
					haddr = val
				case `#/`:
					hrdata = val
				default:
					changed = false
				}
				if changed {
					printState(currentTime, rstn, htrans, haddr, hrdata, ahbReq, wbCyc, bramCyc, txd)
				}
			}
		}
	}
}

var lastState string

func printState(t int64, rstn, htrans, haddr, hrdata, ahbReq, wbCyc, bramCyc, txd string) {
	state := fmt.Sprintf("rst_n:%s htrans:%s haddr:%s hrdata:%s req:%s wb_cyc:%s bram_cyc:%s txd:%s",
		rstn, htrans, haddr, hrdata, ahbReq, wbCyc, bramCyc, txd)
	if state != lastState {
		// Convert ps to ns
		fmt.Printf("[%8.2fns] %s\n", float64(t)/1000.0, state)
		lastState = state
	}
}
