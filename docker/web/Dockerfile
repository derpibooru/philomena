ARG CADDY_VERSION="2.10.2"
ARG CADDY_FS_S3_VERSION=v0.10.0

FROM caddy:$CADDY_VERSION-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/sagikazarmark/caddy-fs-s3@${CADDY_FS_S3_VERSION}

FROM caddy:$CADDY_VERSION-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

EXPOSE 80
