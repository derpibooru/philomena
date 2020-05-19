FROM elixir:1.10.3

# cache bust git repos
ADD https://api.github.com/repos/derpibooru/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
ADD https://api.github.com/repos/derpibooru/mediatools/git/refs/heads/master /tmp/mediatools_version.json

RUN apt-get update; \
    apt-get -qq -y install apt-transport-https; \
    echo "deb https://deb.nodesource.com/node_12.x stretch main" >> /etc/apt/sources.list; \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main" >> /etc/apt/sources.list; \
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -; \
    apt-get update; \
    apt-get -qq -y install inotify-tools postgresql-client build-essential git ffmpeg libavformat-dev libavcodec-dev libswscale-dev nodejs libmagic-dev libpng-dev gifsicle optipng libjpeg-progs librsvg2-bin; \
    cd /tmp; \
    git clone https://github.com/derpibooru/cli_intensities; \
    git clone https://github.com/derpibooru/mediatools; \
    (cd cli_intensities && make install); \
    (cd mediatools && make install); \
    mix local.hex --force; \
    mix local.rebar --force

COPY docker/app/run-development /usr/local/bin/run-development
COPY docker/app/safe-rsvg-convert /usr/local/bin/safe-rsvg-convert
CMD run-development
