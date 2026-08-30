# Out-of-Order Superscalar IITB RISC Processor
**Advanced VLSI Computer Architecture**

## 📌 Project Overview
This project implements a high-performance, **Dual-Issue Superscalar, Out-of-Order (OoO) Execution Processor** based on the IITB RISC Instruction Set Architecture (ISA). It features a highly robust 7-stage pipeline utilizing **Tomasulo's Algorithm** with a Reorder Buffer (ROB) to ensure precise, in-order retirement while maximizing instruction-level parallelism (ILP).

The architecture gracefully handles complex data hazards, control hazards, and memory ordering violations using dynamic register renaming, a speculative dual-branch predictor, and an advanced Load/Store Queue (LSQ) capable of intra-cycle Store-to-Load forwarding.

## 📂 Repository Structure
This repository contains multiple iterations and testing phases of the architecture. The final, fully verified working processor is located in the **`final_update`** directory.

* **`final_update/`** - ⭐ **Final Working Architecture:** Contains the fully debugged, complete superscalar out-of-order core. Run simulations from this directory.
* `branch_testing/` - Isolated experimental branch prediction testing.
* `load_testing/` - LSQ, memory ordering violation, and Store-to-Load forwarding tests.
* `superscaler/` & `superscaler_vhdl/` - Initial superscalar datapath drafts and routing logic.
* `dummy_Experiment/` - Scratchpad for microarchitectural tests.
* `FInal_testing.txt` - Testing instructions and expected array setups.

## 🚀 Key Microarchitectural Features
* **Superscalar Dispatch:** Fetches, decodes, renames, and dispatches up to 2 instructions per clock cycle.
* **Tomasulo's Algorithm (OoO Execution):** Utilizes Reservation Stations (RS_ALU, RS_LSU, RS_Branch) and a Common Data Bus (CDB) with asynchronous combinational snooping to eliminate 1-cycle wakeup delays.
* **Dynamic Register Renaming:** Eliminates WAW and WAR hazards using a Physical Register File (PRF), a Speculative Register Alias Table (RAT), and a dynamically tracked Free List.
* **Reorder Buffer (ROB):** 16-entry circular queue ensuring in-order commit, safe pipeline flushing, and precise exception handling. Includes a Retirement RAT (RRAT) for instant architectural state recovery on branch mispredicts.
* **Dynamic Micro-op (uop) Expansion:** A Mealy Finite State Machine with Datapath (FSMD) dynamically expands Multi-Load (`LM`) and Multi-Store (`SM`) instructions into individual uops while buffering incoming fetch data in a Skid Buffer to preserve superscalar order.
* **Advanced Memory Subsystem:** Independent Load and Store Queues. Supports **Store-to-Load Forwarding** and detects memory ordering violations (younger loads executing before older stores), triggering autonomous pipeline flushes to maintain memory consistency.
* **Dual Branch Predictor:** Speculative execution with autonomous BPU training and misprediction recovery logic. Custom ISA extensions (`BLT`, `BLE`) are fully supported.
* **R0 Program Counter Integration:** Fully supports the IITB RISC specification where `R0` acts as the Program Counter, correctly identifying manual writes to `R0` and triggering speculative PC-redirect flushes.

## 🏗️ Pipeline Architecture (7-Stages)
1. **Fetch (IF):** Dual instruction fetch with speculative PC steering from the Branch Predictor.
2. **Decode (ID):** Micro-op translation, Mealy FSMD expansion for `LM`/`SM`, and 0-cycle combinational bypass for scalar instructions.
3. **Rename (RR):** Allocates PRF tags, updates the Spec_RAT, and performs intra-cycle RAW forwarding if Slot 2 depends on Slot 1.
4. **Dispatch (DI):** Evaluates resource availability (ROB, RS, Free List) and routes packets to execution queues.
5. **Issue (IS):** Out-of-order execution trigger when all dependencies are met via CDB snooping.
6. **Execute / Writeback (EX/WB):** Math/Address calculation and instant asynchronous broadcast over the CDB.
7. **Commit (CM):** In-order retirement by the ROB, freeing physical registers and draining the Store Queue to RAM.

## ⏱️ Instruction Latency Summary
Calculated from Fetch to Commit under ideal (hazard-free) conditions:

| Instruction Class | Min. Latency | Bottleneck Stage |
| :--- | :--- | :--- |
| **ALU / Logic / Jumps** | 7 Cycles | Execution / CDB Writeback |
| **Store Word (SW)** | 7 Cycles | Post-commit RAM write |
| **Load Word (LW/LMF)**| 8-9 Cycles | Data RAM Read Delay |
| **Branch (Correct)** | 7 Cycles | Condition Evaluation |
| **Branch (Mispredict)** | 7 Cycles + Flush | ROB Re-synchronization |
| **Multi-Load/Store** | 7 Cycles + *N* Bits | ID Stage FSM Expansion |

## 🛠️ Advanced Handled Edge-Cases
* **LMF Flag Targeting:** The Load Multiple Flag (`LMF`) instruction uses custom routing to bypass the general-purpose PRF logic, injecting data directly into the independent physical Flag Register tags.
* **Delta-Cycle Race Conditions:** Synchronous 1-cycle alignment registers sit between the ROB commit logic and the RRAT to guarantee that state recovery behaves flawlessly in VHDL simulation.
* **Ghost Ingest Prevention:** Reservation Stations track the `ROB_ID` of ingested packets to prevent duplicate allocations during pipeline stalls.

## 🖥️ Simulation & Debugging (X-Ray Logs)
The processor includes an integrated, industry-grade **X-Ray Logging System**. When simulating in Vivado (or any VHDL testbench environment), the console will output a highly readable, human-formatted trace of the pipeline's internal state.

**What to look for in the console:**
* `[ID X-RAY TRACE]`: Tracks the Mealy FSM state, mask shifting, and UOP Skid Buffer queue depth.
* `[ROUTER X-RAY]`: Displays stall causes, reservation station saturation, and superscalar routing targets.
* `[RS LSU X-RAY]`: Logs Address Generation (AGU) calculations, Store-to-Load forwarding events, and Memory Ordering Violations.
* `[ROB]`: Traces precise, in-order commits, architectural mapping retirements, and full pipeline flushes on mispredictions or `R0` writes.
* `[MMIO]`: Memory-mapped I/O triggers (e.g., writing to Address `0xFFFF`) log explicitly to the console to verify programmatic outputs.

## 📂 Architecture Source Files (`final_update/`)
* `Core_Top.vhd`: The supreme wrapper connecting all subsystems.
* `instruction_fetch.vhd`: PC steering, Dual BPU, and Memory read.
* `ID_stage.vhd`: Dual decoders, Mealy FSM, and Skid Buffer.
* `RR_stage.vhd`: Speculative RAT, Free List, Busy Table, and Dispatch Router.
* `ROB.vhd`: 16-entry Reorder Buffer and Retirement RAT (RRAT).
* `RS_*.vhd`: Tomasulo Reservation Stations (ALU, Branch, LSU).
* `Load_Queue.vhd` / `Store_Queue.vhd`: Speculative memory controllers.
* `alu_execution_unit.vhd` / `AGU.vhd`: Combinational datapaths. 
* `Core_Top_TB.vhd`: Automated testbench evaluating `instruction.mem` against an expected-results array.
