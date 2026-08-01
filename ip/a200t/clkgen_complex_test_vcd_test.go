// SPDX-License-Identifier: Apache-2.0

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
	if err != nil {
		t.Skipf("could not get test db in %q: %v", cwd, err)
	}
	_, cancelFn := context.WithCancelCause(bCtx)
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
