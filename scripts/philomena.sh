#!/usr/bin/env bash
# An entrypoint dev CLI for this repository. You are encouraged to add `scripts/path`
# directory to your PATH to get this CLI available globally as `philomena` in your terminal.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function up {
  local down_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drop-db | --drop-cache) down_args+=("$1") ;;
      *) break ;;
    esac
    shift
  done

  if [[ ${#down_args[@]} -gt 0 ]]; then
    down "${down_args[@]}"
  fi

  step docker compose up --build --no-log-prefix "$@"
}

function down {
  # Delete the database volumes. This doesn't remove the build caches.
  # If you want to clean up everything see the `clean` subcommand.
  local drop_db=false

  # Delete build caches
  local drop_cache=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --drop-db) drop_db=true ;;
      --drop-cache) drop_cache=true ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done

  step docker compose down

  if [[ "$drop_cache" == "true" ]]; then
    info "Dropping build caches..."
    step docker volume rm --force \
      philomena_app_build_data \
      philomena_app_cargo_data \
      philomena_app_deps_data \
      philomena_app_native_data
  fi

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
  # We don't run a `git clean` by default because some developers store dirty scripts
  # and test data in the repo under ignored locations. These are usually harmless,
  # but losing them may be inconvenient. If you really want to do a full clean of
  # files not checked into git, you can use `--git` flag.
  local git=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --git) git=true ;;
      *) die "Unknown option: $1" ;;
    esac
    shift
  done

  step docker compose down --volumes
  step docker container prune --force
  step docker volume prune --all --force
  step docker image prune --all --force
  step sudo chown --recursive "$(id -u):$(id -g)" .

  if [[ "$git" == "true" ]]; then
    step git clean -xfdf
  fi
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

  # Run the given command in the devcontainer via `docker exec`. This script
  # runs it directly here, because `lib.sh` forwards its execution to the
  # devcontainer automatically already.
  exec) "$@" ;;

  # Shortcut for `philomena exec docker compose`
  compose) docker compose "$@" ;;

  *)
    die "See the available sub-commands in ${BASH_SOURCE[0]}"
    ;;
esac
