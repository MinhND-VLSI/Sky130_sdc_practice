# Sky130 SDC Practice — Sequential Adder Timing Closure

A hands-on exercise in writing SDC constraints for a sequential module (with a real
flip-flop, async reset, and an internal feedback path), run through the Yosys
(synthesis) + OpenSTA (static timing analysis) flow on the Sky130 HD standard cell
library.

## Goals

- Understand the core timing path types: Input→Register, Register→Register, Register→Output
- Write the fundamental constraints correctly: `create_clock`, `set_input/output_delay`,
  `set_clock_uncertainty`, `set_false_path`, `set_max_fanout`, `set_max_transition`
- Read and interpret real STA reports (both PASS and FAIL cases)
- Understand WNS (Worst Negative Slack) and TNS (Total Negative Slack)

## Design: `seq_adder.v`

An 8-bit sequential accumulator: on every clock cycle, if `en=1`, `data_out` accumulates
`data_in` (`data_out <= data_out + data_in`). Includes an async active-low reset (`rst_n`).

This module illustrates all 4 timing path types relevant to writing an SDC:

| Path type | Example in the module | Corresponding constraint |
|---|---|---|
| Input port → Register | `data_in`, `en` → FF | `set_input_delay` |
| Register → Register (feedback) | `data_out` → adder logic → `data_out` | checked automatically via `create_clock` |
| Register → Output port | FF → `data_out`, `valid_out` | `set_output_delay` |
| Async reset | `rst_n` | `set_false_path` |

## Flow

**Option A — manual (step by step):**

```bash
# 1. Synthesize RTL -> gate-level netlist with Yosys
yosys -p "read_verilog seq_adder.v; synth -top seq_adder; \
          dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          write_verilog seq_adder_netlist.v"

# 2. Run OpenSTA (via OpenROAD's official Docker image)
docker run -it -v $(pwd):/input openroad/opensta
# inside OpenSTA's TCL shell, pick one:
source /input/run_sta_10ns.tcl   # period=10ns  (PASS)
source /input/run_sta_2ns.tcl    # period=2ns   (VIOLATED)
```

**Option B — via Makefile (recommended):**

```bash
make sta10   # synth + STA with the 10ns constraint (PASS)
make sta2    # synth + STA with the 2ns constraint (VIOLATED)
make clean   # remove the generated netlist
```

The Sky130 HD `.lib` file is not included in this repo (it's part of the PDK and
shouldn't be committed) — get it via [Volare](https://github.com/efabless/volare) or
as part of an OpenLane install. Place it in the repo root before running the flow.

## Experiment 1 — `seq_adder_10ns.sdc` (period = 10ns, 100MHz)

Standard constraint, with plenty of margin for the internal combinational logic
(10 gates, ~4.53ns total delay).

| Check | Data required | Data arrival | Slack | Result |
|---|---|---|---|---|
| Setup (max) | 9.75 ns | 4.53 ns | **+5.22 ns** | MET |
| Hold (min) | 0.12 ns | 0.41 ns | **+0.29 ns** | MET |

Full report: [`results/pass_10ns.txt`](results/pass_10ns.txt)

## Experiment 2 — `seq_adder_2ns.sdc` (period = 2ns, 500MHz)

Deliberately lowered the period to trigger a setup violation — the combinational logic
(4.53ns) simply can't fit inside a 2ns cycle.

| Check | Data required | Data arrival | Slack | Result |
|---|---|---|---|---|
| Setup (max) | 1.75 ns | 4.53 ns | **-2.78 ns** | **VIOLATED** |
| Hold (min) | 0.12 ns | 0.41 ns | +0.29 ns | MET (unchanged) |

```
tns max -32.08
wns max -2.78
```

Full report: [`results/fail_2ns.txt`](results/fail_2ns.txt)

### Notes

- **WNS = -2.78** matches the slack of the path shown above — this is the single worst
  path in the design.
- **TNS = -32.08** is much larger than one path's slack alone → several other endpoints
  (other bits of `data_out[7:0]`) are also violating setup at the same time, adding up.
- **Hold is unaffected** by the period change, since the hold check only compares
  within a single clock cycle (the current edge vs. data arriving right after it) —
  it has nothing to do with the length of the next cycle.
- Takeaway: the combinational logic between two flip-flops (here, an 8-bit add, ~10
  gates) sets the maximum achievable frequency for the design — running faster requires
  shortening that logic chain (e.g., carry-lookahead instead of ripple-carry) or adding
  a pipeline stage.

## Repo structure

```
seq_adder.v                original RTL (sequential, with a real FF)
seq_adder_10ns.sdc          SDC constraint, period=10ns (PASS)
seq_adder_2ns.sdc           SDC constraint, period=2ns  (deliberately VIOLATED, for learning)
run_sta_10ns.tcl             OpenSTA script using seq_adder_10ns.sdc
run_sta_2ns.tcl               OpenSTA script using seq_adder_2ns.sdc
Makefile                     wraps synth + both STA runs into `make sta10` / `make sta2`
results/
  pass_10ns.txt               full report, PASS case
  fail_2ns.txt                full report, VIOLATED case
```
