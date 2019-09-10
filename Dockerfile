FROM ubuntu:18.04

# use apt mirrors
COPY sources.list /etc/apt/sources.list

# Configure directories for ld and pkg-config
RUN echo "/usr/local/ffmpeg/lib\n/usr/local/tensorflow/lib" > /etc/ld.so.conf.d/deps.conf
ENV PKG_CONFIG_PATH $PKG_CONFIG_PATH:/usr/local/ffmpeg/lib/pkgconfig/:/usr/local/tensorflow/lib/pkgconfig/

# Install deps and golang
RUN apt-get update && \
    echo "Installing Ffmpeg deps" && \
    apt-get install -y ca-certificates git make wget x265 libx265-dev pkg-config yasm x264 libx264-dev && \
    # opencv deps
    echo "Installing OpenvCV deps" && \
    apt-get install -y unzip build-essential cmake curl libgtk2.0-dev libtbb2 \
        libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev && \
    # tf deps
    echo "Installing Tensorflow deps" && \
    apt-get install -y zip g++ zlib1g-dev python && \
    # golang
    echo "Installing golang" && \
    apt-get install -y software-properties-common && \
    echo "deb http://ppa.launchpad.net/longsleep/golang-backports/ubuntu bionic main" >> /etc/apt/sources.list.d/go.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 52B59B1571A79DBC054901C0F6BC817356A3D45E && \
    apt-get update && \
    apt-get install -y golang-go && \
    mkdir /go && \
    # cleanup
    rm -rf /var/lib/apt/lists/*
ENV GOPATH /go

#Building Ffmpeg
RUN echo "Building Ffmpeg" && \
    git clone --depth 1 --branch n4.1 https://github.com/ffmpeg/ffmpeg /tmp/ffmpeg && \
    cd /tmp/ffmpeg && \
    ./configure --prefix=/usr/local/ffmpeg --enable-shared --disable-static \
                --disable-manpages --disable-doc --disable-podpages --enable-gpl --enable-libx264 && \
    make -j"$(nproc)" install && \
    ldconfig && \
    rm -r /tmp/ffmpeg

#Installing bazel
ENV BAZEL_VERSION 0.21.0
RUN echo "Installing bazel" && \
    cd /tmp && \
    wget -O bazel-installer.sh \
        https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh && \
    chmod +x bazel-installer.sh && \
    ./bazel-installer.sh && \
    rm /tmp/bazel-installer.sh

ENV LIBRARY_PATH "$LIBRARY_PATH:/usr/local/tensorflow/lib/"

#Build Tensorflow
RUN echo "Building Tensorflow" && \
    git clone --depth 1 --branch v1.13.1 https://github.com/tensorflow/tensorflow /tmp/tensorflow && \
    cd /tmp/tensorflow && \
    # actual build
    yes "" | ./configure && \
    bazel build --config opt --config=nogcp --config=nohdfs --config=noignite --config=nokafka --config=nonccl //tensorflow/tools/lib_package:libtensorflow && \
    # unpacking
    mkdir -p /usr/local/tensorflow && \
    tar -C /usr/local/tensorflow -xzf bazel-bin/tensorflow/tools/lib_package/libtensorflow.tar.gz && \
    ldconfig && \
    rm -r /tmp/tensorflow
