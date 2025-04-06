#!/usr/bin/env bash
# Script to start the docker-compose stack for development.
# You can install a symlink to this script to `/usr/local/bin` with the `init`\
# subcommand, which will make `philomena` available globally.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function up {
  # Delete the database volumes. This doesn't remove the build caches.
  # This is a shortcut to do a `down --drop-db` with a folluwing `up`.
  local drop_db=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drop-db) drop_db=true ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done

  if [[ "$drop_db" == "true" ]]; then
    down --drop-db
  fi

  step exec docker compose up --no-log-prefix
}

function down {
  # Delete the database volumes. This doesn't remove the build caches.
  # If you want to clean up everything see the `clean` subcommand.
  local drop_db=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drop-db) drop_db=true ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done

  step docker compose down

  # If `--drop-db` is enabled it's important to stop all containers to make sure
  # they shut down cleanly. Also, `valkey` stores its data in RAM, so to drop its
  # "database" we need to stop its container.
  #
  # We aren't using `--volumes` parameter with the `docker compose down` because
  # we don't want to delete the build caches, which are also stored in volumes.
  # Instead we remove only DB data volumes separately.
  if [[ "$drop_db" == "true" ]]; then
    info "Dropping databases..."

    step docker volume rm \
      philomena_postgres_data \
      philomena_opensearch_data
  fi
}

# Clean up everything: DBs, build caches, etc.
function clean {
  down --drop-db
  step docker container prune --all --force
  step docker volume prune --all --force
  step docker image prune --all --force
  step sudo chown --recursive "$(id -u):$(id -g)" .

  # We don't run a `git clean` here because some people store dirty scripts
  # and test data in the repo under ignored locations. These are usually harmless,
  # but losing them may be inconvenient.
}

# Initialize the repo for development. See `init.sh` file for details of what
# this means
function init {
  "$(dirname "${BASH_SOURCE[0]}")/init.sh"
}

subcommand="${1:-}"
shift || true

case "$subcommand" in
  up) up "$@" ;;
  down) down "$@" ;;
  clean) clean "$@" ;;
  init) init "$@" ;;
  *)
    die "See the available sub-commands in ${BASH_SOURCE[0]}"
    ;;
esac
