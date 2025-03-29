FROM elixir:1.18.1-alpine

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/6.1 /tmp/ffmpeg_version.json
RUN (echo "https://github.com/philomena-dev/prebuilt-ffmpeg/raw/master"; cat /etc/apk/repositories) > /tmp/repositories \
    && cp /tmp/repositories /etc/apk/repositories \
    && apk update --allow-untrusted \
    && apk add --allow-untrusted \
      bash \
      inotify-tools \
      build-base \
      git \
      ffmpeg \
      ffmpeg-dev \
      npm \
      nodejs \
      file-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      gifsicle \
      optipng \
      libjpeg-turbo-utils \
      librsvg \
      rsvg-convert \
      imagemagick \
      postgresql16-client \
      wget \
      rust \
      cargo \
    && mix local.hex --force \
    && mix local.rebar --force

ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

COPY scripts/lib.sh /var/philomena/scripts/

COPY \
  docker/app/run-development \
  docker/app/run-test \
  docker/app/safe-rsvg-convert \
  docker/app/purge-cache \
  /var/philomena/docker/app/

ENV PATH=$PATH:/root/.cargo/bin:/var/philomena/docker/app
EXPOSE 5173
CMD run-development
