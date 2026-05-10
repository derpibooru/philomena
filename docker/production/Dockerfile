# We need to grab "psql" from the Postgres image for database setup
FROM postgres:17.9-alpine AS pg

#
# Step 1: Build Philomena release
#

FROM elixir:1.18.4-alpine AS builder

WORKDIR /tmp/philomena

ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV PATH=$PATH:/root/.cargo/bin

ADD https://api.github.com/repos/philomena-dev/fiberglass-wrapper/git/refs/heads/master /tmp/fiberglass_wrapper_version.json

# Install dependencies and build tools
RUN apk update --allow-untrusted \
    && apk add build-base git npm nodejs wget rust cargo --allow-untrusted \
    && mix local.hex --force \
    && mix local.rebar --force

# Build fiberglass-wrapper from source
RUN git clone --depth 1 https://github.com/philomena-dev/fiberglass-wrapper /tmp/fiberglass_wrapper \
    && cd /tmp/fiberglass_wrapper \
    && cargo build --release

# Copy repo files into the image
COPY . /tmp/philomena

# Install and compile assets
RUN cd /tmp/philomena/assets \
    && NODE_ENV=development npm install \
    && npm run deploy

# Build the application and create symlinks for easier access
RUN cd /tmp/philomena \
    && mix deps.get \
    && mix release --overwrite

# Digest and copy static assets
RUN mix phx.digest -o /tmp/philomena/_build/prod/rel/philomena/lib/philomena-*/priv/static

#
# Step 2: Copy only the final release into a minimal image
# Also copy psql from the Postgres image
#

FROM alpine:3.23

LABEL org.opencontainers.image.authors="liamwhite <liamwhite@users.noreply.github.com>, Nighty <luna@nighty.cloud>, and contributors"
LABEL org.opencontainers.image.description="The official Philomena Docker image intended for production use."
LABEL org.opencontainers.image.source="https://github.com/philomena-dev/philomena"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

# Install runtime dependencies
# Required by Erlang/Elixir: libncursesw libstdc++ libgcc
# Required by psql: libedit krb5-libs libldap
RUN apk update \
    && apk add --no-cache libncursesw libstdc++ libgcc libedit krb5-libs libldap

# Set up a non-root user to run the application
RUN addgroup -g 1000 -S philomena \
    && adduser -u 1000 -S philomena -G philomena

# Copy the finished release and the config (because of .json files) from the builder stage...
COPY --from=builder --chown=1000:1000 /tmp/philomena/_build/prod/rel/philomena /srv/philomena
COPY --from=builder --chown=1000:1000 /tmp/philomena/config /srv/philomena/config

# Copy fiberglass-wrapper executable too
COPY --from=builder /tmp/fiberglass_wrapper/target/release/fiberglass-wrapper /usr/local/bin/fiberglass-wrapper

# ...and the production scripts from the repository
COPY --chown=1000:1000 docker/production/purge-cache /usr/local/bin/purge-cache
COPY --chown=1000:1000 docker/production/run-cron /usr/local/bin/run-cron
COPY --chown=1000:1000 docker/production/run-cron-daily /usr/local/bin/run-cron-daily
COPY --chown=1000:1000 docker/production/run-production /usr/local/bin/run-production
COPY --chown=1000:1000 docker/production/setup-production /usr/local/bin/setup-production
COPY --chown=1000:1000 docker/production/programs/* /usr/local/bin/

# Copy postgres client.
COPY --from=pg /usr/local/bin/psql /usr/local/bin/psql
COPY --from=pg /usr/local/bin/pg_isready /usr/local/bin/pg_isready
COPY --from=pg /usr/local/lib/libpq.so /usr/local/lib/libpq.so
COPY --from=pg /usr/local/lib/libpq.so.5 /usr/local/lib/libpq.so.5
COPY --from=pg /usr/local/lib/libpq.so.5.17 /usr/local/lib/libpq.so.5.17

# A "philomena" symlink for easier access
RUN ln -sf /srv/philomena/bin/philomena /usr/local/bin/philomena

USER philomena

# Create the static assets symlink as the philomena user
RUN ln -sf /srv/philomena/lib/philomena-*/priv /srv/philomena/priv

WORKDIR /srv/philomena

EXPOSE 4000-4002

CMD ["/usr/local/bin/run-production"]
