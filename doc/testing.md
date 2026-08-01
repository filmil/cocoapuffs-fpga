<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automated testing

Here is an example of using automated testing. This example is the simplest
nontrivial circuit available in this repository. It is a somewhat complicated
clock generator, generating several clocks using the PLL elements built into
the Artix 7 FPGA chip.

The timing diagram of the clock generator is given below. It takes the `CLK` signal
from the board and generates several signals:

- A reset signal `RESET`, which must stay on for at least 10ns in order to reset
  the chip.
- An active-low signal `RESET_N`, which is `RESET` inverted.
- A signal `LOCKED`, which is asserted once the internal PLL element has
  stabilized and the clock signals are reliable.
- Clock signal `CLKOUT0`, which ticks at 100MHz.
- Clock signal `CLKOUT1`, which ticks at 400MHz, used for the DDR3 controller.
- Clock signal `CLKOUT2`, which ticks at 200MHz, used for the DDR3 controller.
- Clock signal `CLKOUT3`, which ticks at 400MHz, and phase shifted by `PI/2`
  with respect to `CLKOUT1`.

![Timing diagram of the clock generator](../doc/clkgen.t.png "Timing diagram of the clock generator")

We can write a testbench file for the clock generator as seen below. We use the
`testing` library to provide a fake board clock, and wire up the unit under
test, so it can generate the output signals that we need to inspect. Note that
the clock generator entity `testing.clkgen` has a parameter `sim_duration`
which we can use to limit the simulation duration without building any other
termination circuitry.  The parameter `clock_period` is set to match the
clock period provided by the Alinx board's clock oscillator, which is 200MHz.

```vhdl
library ieee;
use ieee.std_logic_1164.all;
library testing;
library a200t;
entity clkgen_complex_test is
end entity;
architecture tb of clkgen_complex_test is
    signal clk, reset, reset_n: std_logic;
    signal clkout0, clkout1, clkout2, clkout3, locked: std_logic;
begin
    clkgen0: entity testing.clkgen
        generic map (
            --! Simulation will terminate automatically.
            sim_duration => 10 us,
            clock_period => 5 ns -- 200MHz
        )
        port map (
            clk => clk,
            reset => reset,
            reset_n => reset_n
        );
    uut0: entity a200t.clkgen_complex
        port map(
            clk200MHz => clk,
            clkout0 => clkout0,
            clkout1 => clkout1,
            clkout2 => clkout2,
            clkout3 => clkout3,
            locked => locked
        );
end architecture;
```

We can run the simulation and of course inspect the output in a wave viewer
such as GTKWave. But, as we develop, it becomes onerous to reverify each module
manually for correct functionality. It would be better to create an automated
test which can guard the correct behavior forever, and more importantly,
automatically.

We use the automated testing framework from http://github.com/filmil/go-vcd-parser.
This testing framework allows us to write assertions about the simulation signals
directly.

```go
package a200t_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/filmil/go-vcd-parser/dbq"
)

const MHZ = 1e6

func TestClockGeneratorSignals(t *testing.T) {
	// Load the signals database.
	cwd, err := os.Getwd()
	if err != nil {
		t.Errorf("could not get PWD: %v:", err)
	}
	db, bCtx, err := dbq.GetTestDB()
	_, cancelFn := context.WithCancelCause(bCtx)
	if err != nil {
		cancelFn(err)
		t.Fatalf("could not get test db in %q: %v", cwd, err)
	}
	defer cancelFn(nil)
	q := dbq.New(db)

	// Verify reset happens and lasts long enough.
	reset := q.Signal("//clkgen_complex_test/reset")
	ts1 := reset.FindFirst("1").Testify(t)
	ts2 := reset.FindAfter(ts1, "0").Testify(t)
	if dbq.Diff(ts1, ts2) < 10*time.Nanosecond {
		t.Errorf("reset does not last for long enough")
	}

	// Verify locked happens eventually.
	locked := q.Signal("//clkgen_complex_test/locked")
	lT1 := locked.FindFirst("1").Testify(t)
	if lT1.Before(ts2) {
		t.Errorf("signal %v asserted while reset active", locked)
	}

	// Verify clk exists after locked is asserted, and is a clock of
	// appropriate frequency.
	clk := q.Signal("//clkgen_complex_test/clk")
	cts1 := clk.FindAfter(lT1, "1").Testify(t)
	dbq.Testify00(t, dbq.IsClock(cts1, clk, 200*MHZ))

	// Verify clkout0, same as clk.
	clkout0 := q.Signal("//clkgen_complex_test/clkout0")
	dbq.Testify00(t, dbq.IsClock(cts1, clkout0, 100*MHZ))

	// Verify clkout1, same as clk.
	clkout1 := q.Signal("//clkgen_complex_test/clkout1")
	dbq.Testify00(t, dbq.IsClock(cts1, clkout1, 400*MHZ))

	// Verify clkout2, same as clk.
	clkout2 := q.Signal("//clkgen_complex_test/clkout2")
	dbq.Testify00(t, dbq.IsClock(cts1, clkout2, 200*MHZ))

	// Verify clkout3, same as clk.
	clkout3 := q.Signal("//clkgen_complex_test/clkout3")
	dbq.Testify00(t, dbq.IsClock(cts1, clkout3, 400*MHZ))

	// Verify the phase shift between clkout1 and clkout3 is correct.
	riseClkout1 := clkout1.FindAfter(cts1, "1").Testify(t)
	riseClkout3 := clkout3.FindAfter(riseClkout1, "1").Testify(t)
	if err := dbq.IsDurationApprox(
		riseClkout1, riseClkout3, 1*time.Nanosecond); err != nil {
		t.Errorf("clock phase shift mismatch between %v and %v:\n\t%v",
			riseClkout1, riseClkout3, err)
	}
}
```

We can run the automated test, and if all is well we will see this. Note that
any updated parts of the code will be rebuilt so that the tests are always run
on the most recent version of your code:

```bash
$ bazel test //ip/a200t:clkgen_complex_test_vcd_test
INFO: Analyzed target //ip/a200t:clkgen_complex_test_vcd_test (0 packages loaded, 0 targets configured).
INFO: Found 1 test target...
Target //ip/a200t:clkgen_complex_test_vcd_test up-to-date:
  bazel-bin/ip/a200t/clkgen_complex_test_vcd_test_/clkgen_complex_test_vcd_test
INFO: Elapsed time: 0.149s, Critical Path: 0.00s
INFO: 1 process: 1 internal.
INFO: Build completed successfully, 1 total action
//ip/a200t:clkgen_complex_test_vcd_test                         (cached) PASSED in 0.8s

Executed 0 out of 1 test: 1 test passes.
```

However, test frameworks are the most useful when not everything is fine. A good
test framework must be helpful when there are errors, and must indicate where the
error is located.

Let's artificially introduce an error in our testbench above.

```go
// Verify clkout0, same as clk.
clkout0 := q.Signal("//clkgen_complex_test/clkout0")
//dbq.Testify00(t, dbq.IsClock(cts1, clkout0, 100*MHZ))
dbq.Testify00(t, dbq.IsClock(cts1, clkout0, 10*MHZ))
```

Running the test now shows that there is an error, and what the error is, and
how it manifests itself:

```bash
$ bazel test //ip/a200t:clkgen_complex_test_vcd_test
warning: Git tree '/home/filmil/code/a200t_examples' is dirty
INFO: Analyzed target //ip/a200t:clkgen_complex_test_vcd_test (0 packages loaded, 0 targets configured).
FAIL: //ip/a200t:clkgen_complex_test_vcd_test (see /home/filmil/.cache/bazel/_bazel_filmil/fba57cb1498e5edac648620d88e186c0/execroot/_main/bazel-out/k8-fastbuild/testlogs/ip/a200t/clkgen_complex_test_vcd_test/test.log)
INFO: From Testing //ip/a200t:clkgen_complex_test_vcd_test:
==================== Test output for //ip/a200t:clkgen_complex_test_vcd_test:
--- FAIL: TestClockGeneratorSignals (0.01s)
    clkgen_complex_test_vcd_test.go:52: Testify00 found error:
                signal "//clkgen_complex_test/clkout0" has frequency 10.00MHz:
                unexpected difference between rising and falling edge:
                between timestamps:
                (1) 281ns on "//clkgen_complex_test/clkout0" and
                (2) 286ns on "//clkgen_complex_test/clkout0":
                expected difference: 49ns < 5ns < 48ns, but got difference: 5ns
FAIL
================================================================================
INFO: Found 1 test target...
Target //ip/a200t:clkgen_complex_test_vcd_test up-to-date:
  bazel-bin/ip/a200t/clkgen_complex_test_vcd_test_/clkgen_complex_test_vcd_test
INFO: Elapsed time: 0.771s, Critical Path: 0.60s
INFO: 6 processes: 1 internal, 5 processwrapper-sandbox.
INFO: Build completed, 1 test FAILED, 6 total actions
//ip/a200t:clkgen_complex_test_vcd_test                                  FAILED in 0.1s
  /home/filmil/.cache/bazel/_bazel_filmil/fba57cb1498e5edac648620d88e186c0/execroot/_main/bazel-out/k8-fastbuild/testlogs/ip/a200t/clkgen_complex_test_vcd_test/test.log

Executed 1 out of 1 test: 1 fails locally.
```

