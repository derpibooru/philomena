#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

version=0.11.0

fetch https://github.com/koalaman/shellcheck/releases/download/v$version/shellcheck-v$version.linux.x86_64.tar.xz \
  | step tar -xJf - -C /usr/local/bin --strip-components=1 shellcheck-v$version/shellcheck
