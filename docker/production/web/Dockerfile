ARG CADDY_VERSION="2.10.2"
ARG CADDY_FS_S3_VERSION=v0.11.0

#
# Step 1: Build and digest Philomena static assets
#

FROM elixir:1.18.4-alpine AS philomena

WORKDIR /tmp/philomena

ENV MIX_ENV=prod
ENV NODE_ENV=production

# Install dependencies and build tools
RUN apk update --allow-untrusted \
    && apk add build-base git npm nodejs --allow-untrusted \
    && mix local.hex --force \
    && mix local.rebar --force

# Copy repo files into the image
COPY . /tmp/philomena

# Install and compile assets
RUN cd /tmp/philomena/assets \
    && NODE_ENV=development npm install \
    && npm run deploy

# Get the dependencies and digest the assets, no need to compile the whole app,
# as we only need the static files for the web server.
RUN cd /tmp/philomena \
    && mix deps.get \
    && mix phx.digest --no-compile -o /tmp/philomena/priv/static

#
# Step 2: Build Caddy with required plugins (e.g. S3 file system)
#

FROM caddy:$CADDY_VERSION-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/sagikazarmark/caddy-fs-s3@${CADDY_FS_S3_VERSION} \
    --with github.com/mholt/caddy-ratelimit

#
# Step 3: Assemble the final image
#

FROM caddy:$CADDY_VERSION-alpine

LABEL org.opencontainers.image.authors="liamwhite <liamwhite@users.noreply.github.com>, Nighty <luna@nighty.cloud>, and contributors"
LABEL org.opencontainers.image.description="The official Philomena Web Server image intended for production use."
LABEL org.opencontainers.image.source="https://github.com/philomena-dev/philomena"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

COPY --from=philomena /tmp/philomena/priv/static /var/www
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY docker/production/web/Caddyfile /etc/caddy/Caddyfile
COPY docker/production/web/downtime.html /var/www/downtime.html
COPY docker/production/web/error_50x.html /var/www/error_50x.html

EXPOSE 80
EXPOSE 443
