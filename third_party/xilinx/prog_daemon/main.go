package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"
)

type DaemonConfig struct {
	Pid     int       `json:"pid"`
	Started time.Time `json:"started_time"`
}

type Args struct {
	sshProgram     string
	runtimeDir     string
	binary         string
	daemonLifetime time.Duration
	daemonBinary   string
	binaryArgs     []string
	runFileName    string
	// Write daemon output to this file.
	subdaemonOutfile string
}

const (
	RunFile  = "xilinx_prog_daemon.json"
	HwServer = "hw_server"
)

func CheckPidExists(pid int) bool {
	proc, err := os.FindProcess(pid)
	if err != nil {
		log.Printf("could not find PID: %v: %v", pid, err)
		return false
	}
	if err := proc.Signal(syscall.Signal(0x0)); err != nil {
		log.Printf("no PID %d", pid)
		return false
	}
	return true
}

func terminateByPid(pid int) error {
	proc, err := os.FindProcess(pid)
	if err != nil {
		return fmt.Errorf("could not kill PID: %d: %w", pid, err)
	}

	if err := proc.Signal(syscall.Signal(0x0)); err != nil {
		log.Printf("no PID %d, there seems to be no daemon.", pid)
		return nil
	}

	// If process exists term it, then kill it
	if err := proc.Signal(syscall.SIGTERM); err != nil {
		return fmt.Errorf("could not send SIGTERM to PID: %d: %w", pid, err)
	}

	if err := proc.Signal(syscall.Signal(0x0)); err == nil {
		log.Printf("killing PID %d, after a pause", pid)
		<-time.After(5 * time.Second)
		if err := proc.Signal(syscall.SIGKILL); err != nil {
			return fmt.Errorf("could not send SIGKILL to PID: %d: %w", pid, err)
		}
	}

	return nil
}

func runHwServerDaemon(args Args) error {
	binary := args.daemonBinary
	log.Printf("starting binary: %q, args: %+v", binary, args.binaryArgs)
	cmd, err := StartBinaryNoWait(binary, args.binaryArgs...)
	if err != nil {
		return fmt.Errorf("could not start binary: %q\n\t: %w", binary, err)
	}
	log.Printf("waiting for binary: %q, args: %+v", binary, args.binaryArgs)
	if err := cmd.Wait(); err != nil {
		return fmt.Errorf("could not wait for binary: %q\n\t: %w", binary, err)
	}
	return nil
}

func writeRunFile(runFile string, content DaemonConfig) error {
	o, err := os.Create(runFile)
	if err != nil {
		return fmt.Errorf("could not create file: %q:\n\t%w", runFile, err)
	}
	defer o.Close()
	e := json.NewEncoder(o)
	if err := e.Encode(content); err != nil {
		return fmt.Errorf("could not write file: %q:\n\t%w", runFile, err)
	}
	return nil
}

func readRunFile(runFile string) (DaemonConfig, error) {
	var cfg DaemonConfig
	f, err := os.Open(runFile)
	if err != nil {
		return cfg, err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	if err := d.Decode(&cfg); err != nil {
		return cfg, err
	}
	return cfg, nil
}

func StartBinaryNoWait(binary string, args ...string) (*exec.Cmd, error) {
	cmd := exec.Command(binary, args...)
	cmd.Env = append(os.Environ(), "XILINX_PROG_DAEMON_BINARY=hw_server")
	cmd.Stdin = nil
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("could not Start binary: %q:\n\t%w", binary, err)
	}
	log.Printf("binary %q started", binary)
	return cmd, nil
}

// startDaemon starts a given daemon program.
// Returns the started program's PID, or error in case of failure.
func StartDaemon(args Args) (int, error) {
	exePath, err := os.Executable()
	if err != nil {
		return 0, fmt.Errorf("could not determine executable path: %w", err)
	}
	cmdArgs := []string{"--daemon-binary", args.daemonBinary, "--"}
	cmdArgs = append(cmdArgs, args.binaryArgs...)
	cmd := exec.Command(exePath, cmdArgs...)
	cmd.Env = append(os.Environ(), "XILINX_PROG_DAEMON_BINARY=hw_server")
	cmd.Stdin = nil
	cmd.Stdout = os.Stdout

	// If a flag is specified, use the given output file instead of the default.
	if args.subdaemonOutfile != "" {
		f, err := os.Create(args.subdaemonOutfile)
		if err != nil {
			return 0, fmt.Errorf("could not create outfile: %v: %w", args.subdaemonOutfile, err)
		}
		cmd.Stdout = f
	}
	cmd.Stderr = os.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
	if err := cmd.Start(); err != nil {
		return 0, fmt.Errorf("could not Start daemon:\n\t%w", err)
	}
	return cmd.Process.Pid, nil
}

func runProgDaemon(args Args) error {
	shouldStartDaemon := false

	runFile := filepath.Join(args.runtimeDir, filepath.Base(args.runFileName))
	cfg, err := readRunFile(runFile)
	if err != nil {
		log.Printf("could not read run file, assuming no daemon: %q: %v", runFile, err)
		shouldStartDaemon = true
	} else {
		// content is OK
		now := time.Now()
		daemonDeadline := cfg.Started.Add(args.daemonLifetime)
		if now.After(daemonDeadline) {
			log.Printf("daemon was running for more than %v, restarting",
				daemonDeadline)
			shouldStartDaemon = true
		}
	}

	if cfg.Pid != 0 {
		if !CheckPidExists(cfg.Pid) {
			log.Printf("daemon PID %d does not exist, restarting daemon", cfg.Pid)
			cfg.Pid = 0 // Declare there is no daemon.
			shouldStartDaemon = true
		}
	}

	// Maybe start daemon.
	if shouldStartDaemon {
		// First kill any prior running daemons.
		if cfg.Pid != 0 {
			// There is no info about a daemon, nothing to terminate.
			if err := terminateByPid(cfg.Pid); err != nil {
				return fmt.Errorf("could not kill process: %d:\n\t%w", cfg.Pid, err)
			}
		}
		log.Printf("try to start daemon")

		daemonPid, err := StartDaemon(args)
		if err != nil {
			return fmt.Errorf("could not start new daemon:\n\t%w", err)
		}
		cfg.Pid = daemonPid
		cfg.Started = time.Now()

		if err := writeRunFile(runFile, cfg); err != nil {
			log.Printf("could not write run file: %q:\n\t%v", runFile, err)
		}
	}
	now := time.Now()
	log.Printf("using server daemon PID: %d started this long ago: %v",
		cfg.Pid, now.Sub(cfg.Started))

	return nil
}

func run(args Args) error {
	// Behave as a hardware daemon.
	if args.binary == HwServer {
		log.SetPrefix(fmt.Sprintf("%s[%q]: ", filepath.Base(os.Args[0]), HwServer))
		log.Printf("This is the daemon runner.")
		return runHwServerDaemon(args)
	}
	return runProgDaemon(args)
}

func main() {
	log.SetPrefix(fmt.Sprintf("%s: ", filepath.Base(os.Args[0])))
	log.Printf("startup args: %+v", os.Args)
	args := Args{
		binary: os.Getenv("XILINX_PROG_DAEMON_BINARY"),
	}
	flag.StringVar(&args.sshProgram, "ssh-program", "ssh", "Path to the SSH executable")
	flag.StringVar(&args.runtimeDir, "runtime-dir", "", "Path to the runtime dir")
	flag.StringVar(&args.daemonBinary, "daemon-binary", "", "Path to the daemon binary")
	flag.DurationVar(
		&args.daemonLifetime, "daemon-lifetime", 3*time.Hour,
		"Restart daemon if older than this long")
	flag.StringVar(&args.runFileName, "run-file-name", RunFile, "base path of a run file")
	flag.StringVar(&args.subdaemonOutfile, "subdaemon-outfile", "", "Write subdaemon stdout into this file.")
	flag.Parse()

	if args.daemonBinary == "" {
		log.Printf("flag --daemon-binary=... is required")
		os.Exit(1)
	}

	if args.runtimeDir == "" {
		uid := os.Getuid()
		d := os.Getenv("XDG_RUNTIME_DIR")
		if d == "" {
			d = fmt.Sprintf("/run/user/%d", uid)
		}
		args.runtimeDir = d
	}

	args.binaryArgs = flag.Args()
	if err := run(args); err != nil {
		log.Printf("failed to run: %v", err)
		os.Exit(1)
	}

}
