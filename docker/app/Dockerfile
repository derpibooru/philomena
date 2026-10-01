FROM elixir:1.18.4-alpine

ARG CONTAINER_WORKSPACE=/srv/philomena

ENV PATH=$CONTAINER_WORKSPACE/node_modules/.bin:$PATH
ENV PATH=$CONTAINER_WORKSPACE/scripts/path:$PATH
ENV PATH=$CONTAINER_WORKSPACE/docker/app:$PATH
ENV PATH=/root/.cargo/bin:$PATH

WORKDIR $CONTAINER_WORKSPACE

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
      postgresql17-client \
      curl \
      wget \
      docker-cli-compose \
      docker-cli-buildx \
      caddy \
      openssh

ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install

ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json
RUN git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

# The default `cargo` and `rust` packages in Alpine repo don't include important
# components like `rust-src` (std lib sources), `rustfmt`, and `clippy`.
# It's also more conventional to use rustup for rust toolchain management.
COPY scripts scripts
COPY rust-toolchain.toml rust-toolchain.toml
RUN ./scripts/install/rust.sh \
    && ./scripts/install/shellcheck.sh \
    && ./scripts/install/typos.sh

# `/shell-history` dir is persisted across container rebuilds/restarts
ENV HISTFILE=/shell-history/history

ENTRYPOINT ["run"]
CMD ["run-development"]
EXPOSE 5173
