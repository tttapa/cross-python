BUILD_TRIPLE    := x86_64-unknown-linux-gnu
HOST_TRIPLE     := armv6-rpi-linux-gnueabihf
PYTHON_VERSION  := 3.10.8
PYTHON_SUFFIX   :=
BUILD_PYTHON    := python3.10

TOOLCHAIN       := x-tools-$(HOST_TRIPLE).tar.xz
TOOLCHAIN_URL   := https://github.com/tttapa/toolchains/releases/latest/download
PYTHON_FULL     := Python-$(PYTHON_VERSION)$(PYTHON_SUFFIX)
PYTHON_MAJOR    := $(word 1,$(subst ., ,$(PYTHON_VERSION)))
PYTHON_MINOR    := $(word 2,$(subst ., ,$(PYTHON_VERSION)))
PYTHON_URL      := https://www.python.org/ftp/python

BASE_DIR        := $(shell pwd)
PY_STAGING_DIR  := staging/$(HOST_TRIPLE)/$(PYTHON_MAJOR).$(PYTHON_MINOR)
PY_BUILD_DIR    := build/$(HOST_TRIPLE)/$(PYTHON_VERSION)
DOWNLOAD_DIR    := download
CMAKE_DIR       := staging/$(HOST_TRIPLE)/cmake
TOOLCHAIN_DIR   := staging/$(HOST_TRIPLE)

export PATH := $(BASE_DIR)/$(TOOLCHAIN_DIR)/x-tools/$(HOST_TRIPLE)/bin:$(PATH)

all: python py-build-cmake

.PHONY: all python clean toolchain cmake py-build-cmake

# Toolchain
$(DOWNLOAD_DIR)/$(TOOLCHAIN):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(TOOLCHAIN_URL)/$(TOOLCHAIN) -O $@
	touch $@

$(TOOLCHAIN_DIR)/x-tools: $(DOWNLOAD_DIR)/$(TOOLCHAIN)
	mkdir -p $(TOOLCHAIN_DIR)
	tar xJf $< -C $(TOOLCHAIN_DIR)
	touch $@

toolchain: $(TOOLCHAIN_DIR)/x-tools

# Python
PYTHON_TGZ       := $(DOWNLOAD_DIR)/$(PYTHON_FULL).tgz
PYTHON_CONFIGURE := $(PY_BUILD_DIR)/$(PYTHON_FULL)/configure
PYTHON_MAKEFILE  := $(PY_BUILD_DIR)/$(PYTHON_FULL)/Makefile
PYTHON_BIN       := $(PY_STAGING_DIR)/usr/local/bin/python3

$(PYTHON_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(PYTHON_URL)/$(PYTHON_VERSION)/$(PYTHON_FULL).tgz -O $@
	touch $@

$(PYTHON_CONFIGURE): $(PYTHON_TGZ)
	mkdir -p $(PY_BUILD_DIR)
	tar xzf $< -C $(PY_BUILD_DIR)
	touch $@

$(PYTHON_MAKEFILE): $(PYTHON_CONFIGURE)
	cd $(PY_BUILD_DIR)/$(PYTHON_FULL) && \
	sed -i 's@# Debian/Ubuntu multiarch support.@return@g' setup.py && \
	CONFIG_SITE="$(BASE_DIR)/config.site" \
	./configure \
		--enable-ipv6 \
		--enable-shared \
		--disable-test-modules \
		--build="$(BUILD_TRIPLE)" \
		--host="$(HOST_TRIPLE)" \
		--prefix="/usr/local" \
		--with-build-python="$(BUILD_PYTHON)"
	sed -i 's@libainstall:\( \|	\)all@libainstall:@g' $@

$(PYTHON_BIN): $(PYTHON_MAKEFILE)
	mkdir -p $(PY_STAGING_DIR)
	$(MAKE) -C $(PY_BUILD_DIR)/$(PYTHON_FULL) python python-config -j$(shell nproc)
	$(MAKE) -C $(PY_BUILD_DIR)/$(PYTHON_FULL) altbininstall inclinstall libainstall bininstall DESTDIR=$(BASE_DIR)/$(PY_STAGING_DIR)

python: $(PYTHON_BIN)

$(CMAKE_DIR)/$(HOST_TRIPLE).toolchain.cmake:
	mkdir -p $(CMAKE_DIR)
	$(BUILD_PYTHON) gen-cmake-toolchain.py $(HOST_TRIPLE) $@

cmake: $(CMAKE_DIR)/$(HOST_TRIPLE).toolchain.cmake

$(CMAKE_DIR)/$(HOST_TRIPLE).py-build-cmake.cross.toml: $(CMAKE_DIR)/$(HOST_TRIPLE).toolchain.cmake
	$(BUILD_PYTHON) gen-py-build-cmake-cross-config.py $(HOST_TRIPLE) $@

py-build-cmake: $(CMAKE_DIR)/$(HOST_TRIPLE).py-build-cmake.cross.toml

# Clean
clean:
	rm -rf $(PY_BUILD_DIR) $(PY_STAGING_DIR) $(CMAKE_DIR)
