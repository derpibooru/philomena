FROM elixir:1.10.4

RUN apt-get update \
    && apt-get -qq -y install apt-transport-https \
    && echo "deb https://deb.nodesource.com/node_12.x stretch main" >> /etc/apt/sources.list \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >> /etc/apt/sources.list \
    && wget -qO - "https://www.postgresql.org/media/keys/ACCC4CF8.asc" | apt-key add - \
    && wget -qO - "https://deb.nodesource.com/gpgkey/nodesource.gpg.key" | apt-key add - \
    && apt-get update \
    && apt-get -qq -y install inotify-tools postgresql-client build-essential git ffmpeg libavformat-dev libavcodec-dev libswscale-dev nodejs libmagic-dev libpng-dev gifsicle optipng libjpeg-progs librsvg2-bin \
    && mix local.hex --force \
    && mix local.rebar --force

ADD https://api.github.com/repos/derpibooru/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone https://github.com/derpibooru/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make install

ADD https://api.github.com/repos/derpibooru/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone https://github.com/derpibooru/mediatools /tmp/mediatools \
    && cd /tmp/mediatools \
    && make install

COPY docker/app/run-development /usr/local/bin/run-development
COPY docker/app/safe-rsvg-convert /usr/local/bin/safe-rsvg-convert
CMD run-development
