FROM elixir:1.12.3-alpine

RUN apk update \
    && apk add inotify-tools build-base git npm nodejs file-dev libpng-dev gifsicle optipng libjpeg-turbo-utils librsvg imagemagick postgresql-client wget rust cargo \
       x264-dev x265-dev libvpx-dev lame-dev opus-dev libvorbis-dev yasm \
    && mix local.hex --force \
    && mix local.rebar --force

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/4.4 /tmp/FFmpeg_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/FFmpeg /tmp/FFmpeg \
    && cd /tmp/FFmpeg \
    && ./configure \
      --prefix=/usr \
      --enable-avresample \
      --enable-avfilter \
      --enable-gpl \
      --enable-libmp3lame \
      --enable-libvorbis \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-postproc \
      --enable-pic \
      --enable-pthreads \
      --enable-shared \
      --disable-stripping \
      --disable-static \
      --disable-librtmp \
      --enable-libopus \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

COPY docker/app/run-development /usr/local/bin/run-development
COPY docker/app/run-test /usr/local/bin/run-test
COPY docker/app/safe-rsvg-convert /usr/local/bin/safe-rsvg-convert
COPY docker/app/purge-cache /usr/local/bin/purge-cache
ENV PATH=$PATH:/root/.cargo/bin
CMD run-development
