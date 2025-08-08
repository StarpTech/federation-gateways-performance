#!/usr/bin/env bash
set -Eeuo pipefail

exec env -i RUST_LOG=info /home/azureuser/gateway-rs/target/x86_64-unknown-linux-musl/release/gateway ./supergraph.graphql
