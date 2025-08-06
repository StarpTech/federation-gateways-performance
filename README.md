# GraphQL Federation Gateways Benchmark

This project contains a suite of tools to benchmark and compare the performance of different GraphQL federation gateways.

## Overview

The benchmark process is orchestrated by a `Makefile` and a series of scripts. For each gateway defined in the `gateways/` directory, the process is as follows:

1.  The gateway server is started.
2.  A `monitor.sh` script tracks the CPU and memory usage of the gateway process, logging it to `mem_cpu.csv`.
3.  The `k6` load testing tool runs a test script (`k6.js`) against the gateway. The results are saved to `k6_summary.json`.
4.  After the test, the `toolkit` utility processes `mem_cpu.csv` and `k6_summary.json` to generate a unified `stats.json` file containing key metrics like max CPU/memory, RPS, and latency percentiles.
5.  Finally, the `toolkit` provides a summary view that aggregates the `stats.json` from all tested gateways into a comparative table.

## Project Structure

- `gateways/`: Contains subdirectories for each gateway to be benchmarked. Each gateway needs an `install.sh` to set up dependencies and a `run.sh` to start the server.
- `toolkit/`: A Rust crate with a command-line tool to process and summarize benchmark results.
- `subgraphs/`: Contains the Rust source for the GraphQL subgraphs used for testing.
- `k6.js`: The k6 script for load testing.
- `monitor.sh`: Script to monitor CPU and memory usage of a process.
- `test.sh`: Script to run the benchmark for a single gateway.
- `Makefile`: Provides convenience commands to run the benchmarks.

## Prerequisites

- [Rust](https://www.rust-lang.org/tools/install)
- [k6](https://k6.io/docs/getting-started/installation/)
- A running instance of the subgraphs.

## Usage

1.  **Install Gateway Dependencies**:
    This will run the `install.sh` script for each gateway.
    ```bash
    make install
    ```

2.  **Run the Subgraphs**:
    The subgraphs need to be running for the gateways to connect to them.
    ```bash
    make run-subgraphs
    ```
    This command will block, so run it in a separate terminal.

3.  **Run Benchmarks**:
    You can test a single gateway or all of them.

    *   **Test a single gateway:**
        ```bash
        make test gateway=<gateway_name>
        ```
        Replace `<gateway_name>` with the name of the directory in `gateways/`. For example: `make test gateway=apollo-router`.

    *   **Test all gateways:**
        This will run the test for every gateway in the `gateways` directory and then print a summary table.
        ```bash
        make test-all
        ```

4.  **View Summary Manually**:
    If you have already run the tests and just want to see the summary table again:
    ```bash
    cargo run -p toolkit summary
    ```

    The summary output will look something like this:

    ```
    | Gateway    | RPS     | P99 (ms)   | P95 (ms)   | Count   | MEM (max MB) | CPU (max %) |
    | ---------- | ------- | ---------- | ---------- | ------- | ------------ | ----------- |
    | hive       | 745.21  | 96.91      | 86.37      | 44802   | 60           | 150.00      |
    | cosmo      | 634.06  | 142.16     | 119.17     | 38132   | 123          | 310.00      |
    | grafbase   | 479.78  | 146.87     | 132.13     | 28859   | 94           | 150.00      |
    | apollo     | 360.21  | 199.43     | 179.84     | 21725   | 215          | 344.00      |
    ```
