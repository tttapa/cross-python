FROM ubuntu:jammy as build

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install -y \
        zlib1g-dev libbz2-dev libssl-dev uuid-dev libffi-dev libreadline-dev \
        libsqlite3-dev libbz2-dev libncurses5-dev libreadline6-dev \
        libgdbm-dev liblzma-dev libgdbm-compat-dev \
        gcc g++ make wget && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ARG PYTHON_VERSION

RUN python="Python-${PYTHON_VERSION}" && \
    version_num=$(echo "$PYTHON_VERSION" | grep -Po '^\d+\.\d+\.\d+') && \
    version_suf=${PYTHON_VERSION#"$version_num"} && \
    wget "https://www.python.org/ftp/python/${version_num}/$python.tgz" && \
    tar xzf "$python.tgz" && \
    rm "$python.tgz" && \
    cd "$python" && \
    ./configure --prefix="/usr/local" \
        --enable-ipv6 \
        --enable-shared \
        --disable-test-modules \
        'LDFLAGS=-Wl,-rpath,\$$ORIGIN/../lib' && \
    make -j$(nproc) && \
    staging="$HOME/build-python-${PYTHON_VERSION}" && \
    mkdir -p "$staging" && \
    make altinstall DESTDIR="$staging" && \
    cd .. && \
    rm -rf "$python"
    # --with-lto --enable-optimizations \

FROM ubuntu:jammy

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update -y && \
    apt-get install --no-install-recommends -y \
        ninja-build cmake make bison flex \
        tar xz-utils gzip zip unzip bzip2 \
        ca-certificates wget git && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Add a user called `develop` and add him to the sudo group
RUN useradd -m develop && \
    echo "develop:develop" | chpasswd && \
    adduser develop sudo

USER develop
WORKDIR /home/develop

ARG PYTHON_VERSION

COPY --chown=develop --from=build \
    /root/build-python-${PYTHON_VERSION} \
    /home/develop/opt/build-python-${PYTHON_VERSION}
RUN bash -c 'ln -s build-python-${PYTHON_VERSION} \
    /home/develop/opt/build-python-${PYTHON_VERSION%.*}'
