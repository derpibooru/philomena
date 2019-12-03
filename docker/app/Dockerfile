FROM elixir:1.9.4

RUN apt-get update; \
    apt-get -qq -y install apt-transport-https; \
    echo "deb https://deb.nodesource.com/node_12.x stretch main" >> /etc/apt/sources.list; \
    wget -qO - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -; \
    apt-get update; \
    apt-get -qq -y install build-essential git ffmpeg nodejs libmagic-dev libpng-dev gifsicle optipng libjpeg-progs librsvg2-bin; \
    cd /tmp; \
    git clone https://github.com/derpibooru/cli_intensities; \
    cd cli_intensities; \
    make install; \
    echo -e '#!/bin/sh\nrsvg-convert < "$1" -o "$2"\n' > /usr/local/bin/safe-rsvg-convert; \
    chmod +x /usr/local/bin/safe-rsvg-convert

WORKDIR /srv/philomena
ADD . /srv/philomena

RUN cd /srv/philomena; \
    mix local.hex --force; \
    mix deps.get; \
    cd assets; \
    npm install