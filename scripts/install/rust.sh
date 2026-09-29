#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# Install `rustup` itself
fetch --proto '=https' --tlsv1.2 https://sh.rustup.rs | sh -s -- --default-toolchain none -y

# Use `rustup` to install the toolchain according to the `rust-toolchain.toml` file
step rustup toolchain install
