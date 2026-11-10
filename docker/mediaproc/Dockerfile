FROM rust:1.99.1-slim-trixie AS builder

RUN apt update \
    && apt install -y build-essential git libmagic-dev libturbojpeg0-dev libpng-dev \
       gifsicle optipng libjpeg-turbo-progs librsvg2-bin librsvg2-dev file imagemagick-7.q16hdri \
       libx264-dev libx265-dev libvpx-dev libdav1d-dev libaom-dev libopus-dev \
       libmp3lame-dev libvorbis-dev libwebp-dev libjxl-dev nasm wget

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/9.1 /tmp/ffmpeg_version.json
ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json

RUN wget -qO /tmp/FFmpeg.tar.gz https://github.com/philomena-dev/FFmpeg/archive/refs/heads/release/9.1.tar.gz \
    && wget -qO /tmp/cli_intensities.tar.gz https://github.com/philomena-dev/cli_intensities/archive/refs/heads/master.tar.gz \
    && wget -qO /tmp/mediatools.tar.gz https://github.com/philomena-dev/mediatools/archive/refs/heads/master.tar.gz

RUN cd /tmp \
    && tar -xf FFmpeg.tar.gz \
    && tar -xf cli_intensities.tar.gz \
    && tar -xf mediatools.tar.gz \
    && cd /tmp/FFmpeg-release-9.1 \
    && ./configure \
        --prefix=/usr \
        --disable-everything \
        --disable-stripping \
        --disable-static \
        --disable-ffplay \
        --disable-doc \
        --disable-htmlpages \
        --disable-manpages \
        --disable-podpages \
        --disable-txtpages \
        --disable-protocols \
        --enable-shared \
        --enable-pic \
        --enable-pthreads \
        --enable-gpl \
        --enable-avfilter \
        --enable-bsf=extract_extradata \
        --enable-decoder=aac,apng,av1,gif,h264,hevc,jpeg2000,jpegxl,libaom-av1,libdav1d,libvorbis,libvpx_vp8,libvpx_vp9,mp3,mjpeg,opus,png,vorbis,vp8,vp9,webvtt \
        --enable-demuxer=apng,gif,image2,image_gif_pipe,image_jpeg_pipe,image_png_pipe,image_webp_pipe,matroska,mjpeg,mjpeg_2000,mov,webm \
        --enable-encoder=aac,apng,gif,jpegxl,libmp3lame,libaom-av1,libvorbis,libopus,libvpx_vp8,libvpx_vp9,libx265,libx264,opus,mjpeg,png,vorbis,webvtt \
        --enable-filter=aresample,concat,palettegen,paletteuse,scale,setpts,setsar,settb,split,trim \
        --enable-libaom \
        --enable-libjxl \
        --enable-libdav1d \
        --enable-libopus \
        --enable-libmp3lame \
        --enable-libvpx \
        --enable-libvorbis \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libwebp \
        --enable-muxer=apng,image2,gif,matroska,mp4,webp,webm \
        --enable-parser=aac,gif,h264,hevc,jpeg2000,jpegxl,mjpeg,opus,png,vorbis,vp8,vp9,webp \
        --enable-protocol=concat,data,file,subfile \
    && make -j$(nproc) install \
    && cd /tmp/cli_intensities-master \
    && make -j$(nproc) install \
    && cd /tmp/mediatools-master \
    && make -j$(nproc) install

COPY native/philomena /tmp/philomena

RUN cd /tmp/philomena \
    && cargo build --release -p mediaproc_server

FROM debian:trixie-slim

# Programs and runtime libraries.
RUN apt update \
    && apt install -y gifsicle optipng libjpeg-turbo-progs file imagemagick-7.q16hdri \
       libvpx9 libmp3lame0 libopus0 libvorbis0a libvorbisenc2 libx264-164 \
       libx265-215 librsvg2-2 librsvg2-bin \
    && rm -rf /var/lib/apt/lists/*

# Copy additional ffmpeg libs, as well as all the binaries.
COPY --from=builder /usr/lib/libav* /usr/lib
COPY --from=builder /usr/lib/libswresample* /usr/lib
COPY --from=builder /usr/lib/libswscale* /usr/lib
COPY --from=builder /usr/bin/ffmpeg /usr/bin/ffmpeg
COPY --from=builder /usr/bin/ffprobe /usr/bin/ffprobe
COPY --from=builder /tmp/philomena/target/release/mediaproc_server /usr/bin/mediaproc_server
COPY --from=builder /usr/local/bin/image-intensities /usr/bin/image-intensities
COPY --from=builder /usr/local/bin/mediastat /usr/bin/mediastat
COPY --from=builder /usr/local/bin/svgstat /usr/bin/svgstat
COPY --from=builder /usr/local/bin/mediathumb /usr/bin/mediathumb
COPY docker/mediaproc/safe-rsvg-convert /usr/bin/safe-rsvg-convert
COPY docker/mediaproc/policy.xml /etc/ImageMagick-7/policy.xml

# Set up unprivileged user account.
RUN useradd -ms /bin/bash mediaproc
USER mediaproc
WORKDIR /home/mediaproc
ENV RUST_LOG=trace
CMD ["/usr/bin/mediaproc_server", "0.0.0.0:1500"]
