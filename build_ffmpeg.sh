#!/bin/bash

sudo apt-get update
sudo apt-get -y install autoconf automake build-essential libass-dev libfreetype6-dev \
  libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev \
  libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texinfo zlib1g-dev yasm libmp3lame-dev \
  libopus-dev libspeex-dev libx264-dev libfdk-aac-dev libvpx-dev x264 #libx265-dev x265

[[ -d "$HOME/ffmpeg_sources" ]] || mkdir "$HOME/ffmpeg_sources"
cd "$HOME/ffmpeg_sources"
rm tar xjvf ffmpeg-snapshot.tar.bz2*
wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar xjvf ffmpeg-snapshot.tar.bz2
cd ffmpeg
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libtheora \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  --enable-libspeex \
  --enable-nvenc \
  --enable-x11grab

PATH="$HOME/bin:$PATH" make
make install
make distclean
hash -r

echo "MANPATH_MAP $HOME/bin $HOME/ffmpeg_build/share/man" >> ~/.manpath
