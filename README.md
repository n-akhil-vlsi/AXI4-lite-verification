# AXI4-Lite Slave Verification (UVM)

A full UVM testbench built from scratch to verify an AXI4-Lite slave — a 16-word memory-mapped register block — including protocol-level assertions, functional coverage, and a fully self-checking scoreboard against a reference shadow-memory model.

---

## Overview

The Design Under Test (DUT) is `axils`, a 16-word (64-byte) AXI4-Lite slave built around two independent finite-state machines:

- **Write FSM** — handles the AW/W handshake, writes `wdata` into `mem[]` under byte-strobe control (`wstrb`), and returns a `bresp` (OKAY/SLVERR)
- **Read FSM** — handles the AR handshake, fetches from `mem[]`, and returns `rdata` + `rresp` (OKAY/SLVERR)

Both FSMs run concurrently and independently, so a write and a read can be in flight on the same clock without interfering with each other. An access is legal only if the address is **word-aligned** and **within range** (`addr < NUM_WORDS*4`); anything else returns `SLVERR` with no memory side-effect.

This repo verifies that DUT using a **class-based UVM environment**, layered on top of **SystemVerilog Assertions (SVA)** bound directly to the DUT ports for cycle-accurate handshake checks, and a **covergroup** for functional coverage closure.

---

## Key Features

- ✅ Full UVM agent (driver, monitor, sequencer) driving a single unified transaction type
- ✅ Config-object-driven environment (`num_words`, `addr_hi_bit` shared across every component via `axi4lite_config_obj`)
- ✅ 11 directed test scenarios plus one master "run everything" test
- ✅ SVA bound directly into the DUT interface — checks AXI4 handshake legality (VALID-stability, response-code legality, no-X), not just data correctness
- ✅ Self-checking scoreboard with a byte-accurate **shadow memory model** that mirrors the DUT's `addr_ok()` legality logic and `wstrb`-masked writes
- ✅ Functional coverage on write/read completion, response codes, per-word address coverage, WSTRB pattern coverage, and write/read cross coverage
- ✅ Directed edge-case coverage: misaligned addresses, out-of-range addresses, back-to-back skewed handshakes, VALID/READY stalling, and long response backpressure
- ✅ Fully randomized stress test (150 items, `assert(item.randomize())`) layered on top of the directed suite

---

## Verification Architecture

```
                          ┌─────────────────────────────┐
                          │     axi4lite_base_test       │
                          │  (build_phase + do_initial_  │
                          │   reset + per-test scenario) │
                          └──────────────┬───────────────┘
                                         │ starts
                          ┌──────────────▼───────────────┐
                          │         axi4lite_env          │
                          │  ┌────────────┐ ┌───────────┐ │
                          │  │axi4lite_agt│ │scoreboard │ │
                          │  └─────┬──────┘ └─────▲─────┘ │
                          │        │              │       │
                          │  ┌─────▼──────┐       │       │
                          │  │ coverage   │◄──────┤       │
                          │  └────────────┘       │       │
                          └────────┬──────────────┼───────┘
                                   │               │
                    ┌──────────────┼───────────────┘
                    │              │
             ┌──────▼─────┐ ┌──────▼─────┐
             │ sequencer  │ │  monitor   │──► samples axi4lite_if,
             └──────┬─────┘ │            │    packages observed
                    │       └────────────┘    transactions
             ┌──────▼─────┐
             │   driver   │──► drives axi4lite_if
             └──────┬─────┘
                    │
             ┌──────▼──────┐        ┌─────────────┐
             │ axi4lite_if │◄──────►│    axils     │
             └─────────────┘        │  (DUT slave) │
                                     └──────┬───────┘
                                            │ bound
                                     ┌──────▼───────┐
                                     │ axi4lite_sva  │
                                     │ (assertions)  │
                                     └───────────────┘
```

**Transaction model:** a single `axi4lite_seq_item` carries `rst`, `do_write`, `do_read`, address-legality mode (`ADDR_OK` / `ADDR_MISALIGNED` / `ADDR_OOR`), data, `wstrb`, and optional per-channel skew/stall knobs (`aw_delay_cycles`, `w_delay_cycles`, `bready_delay_cycles`, `rready_delay_cycles`, `resp_hold_cycles`) — all in one class, so a directed sequence can drive write-only, read-only, or simultaneous write+read scenarios, plus timing edge cases, without separate transaction types.

---

## Test Scenarios

| Test | What it does |
|---|---|
| `axi4lite_reset_test` | Asserts and releases reset, then issues one write + one read to confirm the DUT recovers cleanly |
| `axi4lite_write_only_test` | Writes all 16 word addresses once each, back-to-back |
| `axi4lite_read_only_test` | Reads all 16 word addresses once each |
| `axi4lite_write_read_together_test` | Drives a write and a read simultaneously (address channels offset by one word), checking the two FSMs run concurrently without interference |
| `axi4lite_back_to_back_test` | Skews AWVALID against WVALID (alternating which one arrives late) across consecutive writes with no idle gap, stressing the `aw_hs_done`/`w_hs_done` latch |
| `axi4lite_misaligned_addr_test` | Forces non-word-aligned addresses on both channels, checks SLVERR is returned and no illegal write occurs |
| `axi4lite_out_of_range_test` | Forces addresses beyond `NUM_WORDS*4`, checks SLVERR and that no stale/X data escapes on the read side |
| `axi4lite_wstrb_test` | Sweeps every single-byte and half-word WSTRB pattern on the same address, verifying untouched bytes are preserved across writes |
| `axi4lite_stall_test` | Randomly delays BREADY/RREADY by 0-4 cycles per transaction, checking the DUT doesn't assume an always-ready master |
| `axi4lite_response_backpressure_test` | Holds BREADY/RREADY low for a long, fixed 50-cycle stretch, verifying BVALID/RVALID stay asserted unglitched for the entire hold |
| `axi4lite_random_test` | Fully randomized stress sequence (150 items) covering resets, writes, reads, address legality, and channel skew all mixed together |
| `axi4lite_all_scenarios_test` | Master sequence — runs every scenario above back to back in a single test |

---

## Protocol Checks (SVA)

Bound directly into the DUT's interface signals (`axi4lite_sva.sv`), independent of the scoreboard's transaction-level checks:

- `AWVALID`/`WVALID`/`ARVALID` must never drop before their corresponding `READY` is seen (AXI4 stability rule)
- `BVALID`/`RVALID` must stay asserted until `BREADY`/`RREADY` is seen — directly backs up the response-backpressure test
- `BRESP`/`RRESP` may only ever be `OKAY` or `SLVERR` — this slave never returns `EXOKAY`/`DECERR`
- `BVALID`/`RVALID` must never go to `X`/`Z` once out of reset
- Cover properties on write/read transfer completion and on SLVERR occurring on each channel

---

## Functional Coverage

Sampled per-transaction in `axi4lite_coverage.sv`:

- Write/read completion (`write_done`, `read_done`) and their cross — captures simultaneous write+read completion
- `bresp`/`rresp` — OKAY vs. SLVERR — and their cross, so a SLVERR on one channel while the other returns OKAY is explicitly covered
- Per-word address coverage on both `awaddr[5:2]` and `araddr[5:2]` (all 16 words), sampled only on successful (OKAY) transfers
- WSTRB pattern coverage: all-bytes, upper/lower half-word, and each individual byte lane

---

## Repository Structure

```
AXI4_Lite_Verification/
├── README.md
├── RTL/
│   └── axi4lite_slave.v            # DUT: axils, 16-word AXI4-Lite slave
├── UVM/
│   ├── axi4lite_if.sv               # DUT interface
│   ├── axi4lite_sva.sv              # protocol assertions (bound into axils)
│   ├── axi4lite_tb_top.sv           # testbench top, clock/reset gen, DUT bind
│   ├── axi4lite_seq_item.sv         # transaction class
│   ├── axi4lite_sequence.sv         # all sequence scenarios
│   ├── axi4lite_sequencer.sv
│   ├── axi4lite_driver.sv
│   ├── axi4lite_monitor.sv
│   ├── axi4lite_agent.sv
│   ├── axi4lite_config_obj.sv       # num_words / addr_hi_bit shared config
│   ├── axi4lite_scoreboard.sv       # shadow-memory reference model
│   ├── axi4lite_coverage.sv         # functional coverage model
│   └── axi4lite_env.sv
├── TEST/
│   └── axi4lite_test.sv             # all uvm_test classes
└── SIM/
    ├── axi4lite_reset_test/
    ├── axi4lite_write_only_test/
    ├── axi4lite_read_only_test/
    ├── axi4lite_write_read_together_test/
    ├── axi4lite_back_to_back_test/
    ├── axi4lite_misaligned_addr_test/
    ├── axi4lite_out_of_range_test/
    ├── axi4lite_wstrb_test/
    ├── axi4lite_stall_test/
    ├── axi4lite_response_backpressure_test/
    ├── axi4lite_random_test/
    └── axi4lite_all_scenarios_test/
        # each folder holds Tcl_console_output.txt (UVM log + scoreboard
        # summary) and waveform screenshot(s) for that test
```

---

## Results Summary

Every test below passed with **0 UVM_ERROR / 0 UVM_FATAL**, verified against the scoreboard's shadow-memory model:

| Test | Writes | Reads | Write SLVERR (exp) | Read SLVERR (exp) | Coverage | Result |
|---|---|---|---|---|---|---|
| reset | 1 | 1 | 0 | 0 | 47.42% | PASS |
| write_only | 17 | 1 | 0 | 0 | 57.84% | PASS |
| read_only | 1 | 17 | 0 | 0 | 57.84% | PASS |
| write_read_together | 9 | 9 | 0 | 0 | 57.84% | PASS |
| back_to_back | 7 | 1 | 0 | 0 | 50.89% | PASS |
| misaligned_addr | 7 | 7 | 6 | 6 | 64.09% | PASS |
| out_of_range | 7 | 7 | 6 | 6 | 64.09% | PASS |
| wstrb | 9 | 9 | 0 | 0 | 58.33% | PASS |
| stall | 6 | 6 | 0 | 0 | 53.67% | PASS |
| response_backpressure | 5 | 5 | 0 | 0 | 51.59% | PASS |
| random | 96 | 106 | 79 | 91 | 85.42% | PASS |

*(Coverage percentages are `cg.get_inst_coverage()` from that individual test run; running `axi4lite_all_scenarios_test` closes coverage across every scenario in one shot.)*

---

## Running the Simulation

**Tool used:** Xilinx Vivado Simulator (XSIM) — this project was built and run entirely in Vivado.

1. Create a new RTL project in Vivado and add the sources:
   - Design sources → `RTL/axi4lite_slave.v`
   - Simulation sources → everything under `UVM/` and `TEST/`
2. Set `axi4lite_tb_top` as the simulation top module.
3. Under **Simulation Settings**, add the UVM library:
   - `Simulation → xelab.more_options` → add `-L uvm`
4. Click **Run Simulation → Run Behavioral Simulation**.
5. To switch tests, set `UVM_TESTNAME` as a simulation plusarg (Simulation Settings → xsim.simulate.more_options → `-testplusarg UVM_TESTNAME=axi4lite_random_test`), or edit the default test in `axi4lite_tb_top.sv`.

---

## Requirements

- Xilinx Vivado (Design Suite), with the built-in UVM 1.2 library (`-L uvm` at elaboration)
- No other simulator is required — this project was verified entirely on Vivado XSIM

---

## Author

**Akhil N** — B.Tech ECE
GitHub: [n-akhil](https://github.com/n-akhil)
