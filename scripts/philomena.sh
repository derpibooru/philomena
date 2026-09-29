#!/usr/bin/env bash
# An entrypoint dev CLI for this repository. You are encouraged to add `scripts/path`
# directory to your PATH to get this CLI available globally as `philomena` in your terminal.

set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"


# Devcontainer runs in the `app` service. We must make sure this service stays
# intact during development, so all docker compose operations that might recreate
# or remove the containers/volumes should exclude it and its volumes.
mapfile -t services_except_app < <(docker compose config --services | grep -v app)

services=()
volumes=()

if [[ "${DEVCONTAINER:-0}" == "1" ]]; then
  services=("${services_except_app[@]}")
  mapfile -t volumes < <(docker compose config --volumes | grep -v -e shell_history -e cargo_registry -e cargo_git)
fi

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

  if [[ "${DEVCONTAINER:-0}" == "1" ]]; then
    step docker compose build "${services[@]}"
    step docker compose up --wait "${services[@]}"
    step run-development
  else
    step docker compose up --build --no-log-prefix
  fi
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

  step docker compose down "${services[@]}"

  if [[ "$drop_cache" == "true" ]]; then
    drop_cache
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

function test {
  step docker compose build "${services[@]}"
  step docker compose up --wait "${services_except_app[@]}"

  if [[ "${DEVCONTAINER:-0}" == "1" ]]; then
    step run-test
  else
    step docker compose run --rm app run-test
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

  drop_cache
  step docker compose down "${services[@]}"
  step docker volume rm -f "${volumes[@]//#/philomena_}"
  step docker container prune --force
  step docker volume prune --all --force
  step docker image prune --all --force
  step docker buildx prune --all --force

  if [[ "$git" == "true" ]]; then
    step git clean -xfdf
  fi
}

function drop_cache {
  info "Dropping build caches..."
  step rm -rf _build .cargo deps priv/native
}

subcommand="${1:-}"
shift || true

case "$subcommand" in
  up) up "$@" ;;
  down) down "$@" ;;
  test) test "$@" ;;
  clean) clean "$@" ;;

  *)
    die "See the available sub-commands in ${BASH_SOURCE[0]}"
    ;;
esac
