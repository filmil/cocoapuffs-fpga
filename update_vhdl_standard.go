package main

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/bitfield/script"
)

func main() {
	err := filepath.WalkDir(".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}

		if filepath.Base(path) == "BUILD.bazel" {
			updateBuildFile(path)
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

var targetRegex = regexp.MustCompile(`(?s)(vivado_library|vhdl_library|vhdl_test)\s*\((.*?)\)`)
var nameRegex = regexp.MustCompile(`name\s*=\s*["'](.*?)["']`)
// Matches standard = "..." only if NOT preceded by #
var standardRegex = regexp.MustCompile(`(?m)^[^#]*?standard\s*=\s*["'](.*?)["']`)
// Matches standard = "..." even if commented
var anyStandardRegex = regexp.MustCompile(`standard\s*=\s*["'](.*?)["']`)
var vhdl1993Regex = regexp.MustCompile(`\s*vhdl1993\s*=\s*(True|False),?`)

func updateBuildFile(path string) {
	content, err := script.File(path).String()
	if err != nil {
		fmt.Printf("Failed to read %s: %v\n", path, err)
		return
	}

	newContent := targetRegex.ReplaceAllStringFunc(content, func(m string) string {
		// m is the whole target call, e.g., vhdl_library(...)
		
		// Remove vhdl1993
		m = vhdl1993Regex.ReplaceAllString(m, "")

		if standardRegex.MatchString(m) {
			// Replace existing uncommented standard
			m = standardRegex.ReplaceAllStringFunc(m, func(s string) string {
				// s is the line or part of it that matched
				return anyStandardRegex.ReplaceAllString(s, `standard = "2019"`)
			})
		} else {
			// Either it's missing OR it's commented out.
			// If it's commented out, let's remove the commented out one and add a new one.
			m = anyStandardRegex.ReplaceAllString(m, "") // This might leave empty lines or comments, but it's okay for now.
			
			// Add standard after name
			if nameRegex.MatchString(m) {
				m = nameRegex.ReplaceAllString(m, `$0,`+"\n"+`    standard = "2019"`)
				// Fix potential double comma if name already had one
				m = strings.Replace(m, `",,`, `",`, -1)
				m = strings.Replace(m, `',,`, `',`, -1)
			}
		}
		return m
	})

	if newContent != content {
		err = os.WriteFile(path, []byte(newContent), 0644)
		if err != nil {
			fmt.Printf("Failed to write %s: %v\n", path, err)
		} else {
			fmt.Printf("Updated %s\n", path)
		}
	}
}
