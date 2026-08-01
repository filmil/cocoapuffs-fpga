package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

func main() {
	err := filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || filepath.Base(path) != "BUILD.bazel" {
			return nil
		}

		content, err := ioutil.ReadFile(path)
		if err != nil {
			return err
		}

		checkDuplicates(path, string(content))
		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// targetRegex matches targets like: type( name = "name", ... )
// It's a bit simplified but should work for most Bazel targets.
var targetRegex = regexp.MustCompile(`(?s)([a-z0-9_]+)\s*\((.*?)\)`)

func checkDuplicates(path, content string) {
	matches := targetRegex.FindAllStringSubmatch(content, -1)
	for _, match := range matches {
		targetType := match[1]
		body := match[2]

		// Extract target name
		nameRegex := regexp.MustCompile(`name\s*=\s*"([^"]+)"`)
		nameMatch := nameRegex.FindStringSubmatch(body)
		targetName := "unknown"
		if len(nameMatch) > 1 {
			targetName = nameMatch[1]
		}

		if !strings.Contains(targetType, "library") && !strings.Contains(targetType, "test") && !strings.Contains(targetType, "simulation") && !strings.Contains(targetType, "synthesis") {
			continue
		}

		lines := strings.Split(body, "\n")
		counts := make(map[string]int)
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.Contains(line, "=") {
				// Avoid matching inside strings if possible, though Bazel doesn't have many = in strings for these targets.
				key := strings.TrimSpace(strings.Split(line, "=")[0])
				if key != "" && !strings.HasPrefix(line, "#") {
					counts[key]++
				}
			}
		}

		for key, count := range counts {
			if count > 1 && key == "standard" {
				fmt.Printf("File: %s, Target: %s (%s), Key: %s, Count: %d\n", path, targetName, targetType, key, count)
			}
		}
	}
}
