#!/usr/bin/env bash
#
# This script runs shellcheck on all shell scripts in the repository.
# It exists because shellcheck doesn't attempt to automatically discover
# shell scripts and requires specifying the file paths explicitly.
#
# This is somewhat understandable, because not all shell scripts use
# obvious file extensions like `.sh`. So, we discover such files by
# checking if they have one of the expected shebang lines at the beginning.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function shell_script_files {
  git ls-files "*.sh"
  git grep --files-with-matches '^#!/usr/bin/env bash'
  git grep --files-with-matches '^#!/usr/bin/env sh'
}

mapfile -t files < <(shell_script_files "$@" | sort -u)

step shellcheck --source-path SCRIPTDIR "${files[@]}"
