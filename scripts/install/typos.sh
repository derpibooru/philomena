#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

version=1.39.0

fetch https://github.com/crate-ci/typos/releases/download/v$version/typos-v$version-x86_64-unknown-linux-musl.tar.gz \
  | step tar -xzf - -C /usr/local/bin ./typos
