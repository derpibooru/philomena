ARG CADDY_VERSION="2.9.1"

FROM caddy:$CADDY_VERSION-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/sagikazarmark/caddy-fs-s3

FROM caddy:$CADDY_VERSION-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

EXPOSE 80
