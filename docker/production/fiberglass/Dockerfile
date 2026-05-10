FROM ghcr.io/philomena-dev/fiberglass:2025-12-10

LABEL org.opencontainers.image.authors="liamwhite <liamwhite@users.noreply.github.com>, Nighty <luna@nighty.cloud>, and contributors"
LABEL org.opencontainers.image.description="Legacy Philomena image processing tools, used by Philomena 1.2.x and older. Deprecated in favor of Mediaproc."
LABEL org.opencontainers.image.source="https://github.com/philomena-dev/philomena"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"

WORKDIR /tmp/fiberglass-server

COPY docker/production/fiberglass/fiberglass-server.ru /tmp/fiberglass-server/fiberglass-server.ru

USER root

RUN apk add ruby ruby-dev build-base rsvg-convert \
    && gem install rack puma rackup base64 \
    && apk del build-base \
    && rm -f /sbin/apk \
    && rm -rf /etc/apk /lib/apk /usr/share/apk /var/lib/apk

USER fiberglass

CMD puma -b tcp://0.0.0.0:8080 -w 8 -t 1:1 /tmp/fiberglass-server/fiberglass-server.ru
