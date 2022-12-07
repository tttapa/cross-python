BUILD_TRIPLE    := x86_64-unknown-linux-gnu
HOST_TRIPLE     := armv6-rpi-linux-gnueabihf
PYTHON_VERSION  := 3.10.9
PYTHON_SUFFIX   :=
BUILD_PYTHON    := python3.10
SHELL           := bash

BASE_DIR        := $(shell pwd)
STAGING_DIR     := staging/$(HOST_TRIPLE)
BUILD_DIR       := build/$(HOST_TRIPLE)
DOWNLOAD_DIR    := download
TOOLCHAIN_DIR   := $(STAGING_DIR)
HOST_ARCH       := $(word 1,$(subst -, ,$(HOST_TRIPLE)))

TOOLCHAIN       := x-tools-$(HOST_TRIPLE).tar.xz
TOOLCHAIN_URL   := https://github.com/tttapa/toolchains/releases/latest/download
PYTHON_FULL     := Python-$(PYTHON_VERSION)$(PYTHON_SUFFIX)
PYTHON_MAJOR    := $(word 1,$(subst ., ,$(PYTHON_VERSION)))
PYTHON_MINOR    := $(word 2,$(subst ., ,$(PYTHON_VERSION)))
PYTHON_URL      := https://www.python.org/ftp/python
PY_STAGING_DIR  := $(STAGING_DIR)/$(PYTHON_FULL)
PY_BUILD_DIR    := $(BUILD_DIR)/$(PYTHON_VERSION)

export PATH := $(BASE_DIR)/$(TOOLCHAIN_DIR)/x-tools/$(HOST_TRIPLE)/bin:$(PATH)

all:
	@echo No default target

.PHONY: all python clean toolchain cmake py-build-cmake

# Toolchain
$(DOWNLOAD_DIR)/$(TOOLCHAIN):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(TOOLCHAIN_URL)/$(TOOLCHAIN) -O $@
	touch -c $@

$(TOOLCHAIN_DIR)/x-tools: $(DOWNLOAD_DIR)/$(TOOLCHAIN)
	mkdir -p $(TOOLCHAIN_DIR)
	tar xJf $< -C $(TOOLCHAIN_DIR)
	touch -c $@

toolchain: $(TOOLCHAIN_DIR)/x-tools

# Python
PYTHON_TGZ       := $(DOWNLOAD_DIR)/$(PYTHON_FULL).tgz
PYTHON_CONFIGURE := $(PY_BUILD_DIR)/$(PYTHON_FULL)/configure
PYTHON_MAKEFILE  := $(PY_BUILD_DIR)/$(PYTHON_FULL)/Makefile
PYTHON_BIN       := $(PY_STAGING_DIR)/usr/local/bin/python3

$(PYTHON_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(PYTHON_URL)/$(PYTHON_VERSION)/$(PYTHON_FULL).tgz -O $@
	touch -c $@

$(PYTHON_CONFIGURE): $(PYTHON_TGZ)
	mkdir -p $(PY_BUILD_DIR)
	tar xzf $< -C $(PY_BUILD_DIR)
	touch -c $@

$(PYTHON_MAKEFILE): $(PYTHON_CONFIGURE)
	cd $(PY_BUILD_DIR)/$(PYTHON_FULL) && \
	{ [ ! -e setup.py ] || \
		sed -i 's@# Debian/Ubuntu multiarch support.@return@g' setup.py; } && \
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
	ln -sf $(PYTHON_FULL) $(STAGING_DIR)/python$(PYTHON_MAJOR).$(PYTHON_MINOR)

python: $(PYTHON_BIN)

# PyPy
PYPY_URL         := https://downloads.python.org/pypy
PYPY_VERSION     := 7.3.9
PYPY_ARCH        := $(HOST_ARCH:x86_64=linux64)
PYPY_FULL        := pypy$(PYTHON_MAJOR).$(PYTHON_MINOR)-v$(PYPY_VERSION)-$(PYPY_ARCH)
PYPY_TGZ         := $(DOWNLOAD_DIR)/$(PYPY_FULL).tar.bz2
PYPY_STAGING_DIR := $(STAGING_DIR)/$(PYPY_FULL)
PYPY_INC         := $(PYPY_STAGING_DIR)/include/pypy$(PYTHON_MAJOR).$(PYTHON_MINOR)/Python.h

$(PYPY_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(PYPY_URL)/$(PYPY_FULL).tar.bz2 -O $@
	touch -c $@

$(PYPY_INC): $(PYPY_TGZ)
	tar xjf $< -C $(STAGING_DIR) 
	touch -c $@
	rm -rf \
		$(PYPY_STAGING_DIR)/bin/{pypy*,python*,*.debug} \
		$(PYPY_STAGING_DIR)/lib/{tcl*,tk*,libgdbm.so*,liblzma.so*,libpanelw.so*,libsqlite3.so*,libtcl*.so*,libtk*.so*,pypy*}
	ln -sf $(PYPY_FULL) $(STAGING_DIR)/pypy$(PYTHON_MAJOR).$(PYTHON_MINOR)

pypy: $(PYPY_INC)

.PHONY: pypy

# CMake toolchain
CMAKE_DIR       := $(STAGING_DIR)/cmake
CMAKE_TOOLCHAIN := $(CMAKE_DIR)/$(HOST_TRIPLE).toolchain.cmake

$(CMAKE_TOOLCHAIN): gen-cmake-toolchain.py
	mkdir -p $(CMAKE_DIR)
	$(BUILD_PYTHON) $< $(HOST_TRIPLE) $@

cmake: $(CMAKE_TOOLCHAIN)

$(CMAKE_DIR)/$(HOST_TRIPLE).py-build-cmake.cross.toml: gen-py-build-cmake-cross-config.py $(CMAKE_TOOLCHAIN)
	$(BUILD_PYTHON) $< $(HOST_TRIPLE) $@

py-build-cmake: $(CMAKE_DIR)/$(HOST_TRIPLE).py-build-cmake.cross.toml

# FFTW
FFTW_URL         := https://fftw.org
FFTW_VERSION     := 3.3.10
FFTW_FULL        := fftw-$(FFTW_VERSION)
FFTW_TGZ         := $(DOWNLOAD_DIR)/$(FFTW_FULL).tar.gz
FFTW_BUILD_DIR   := $(BUILD_DIR)
FFTW_CMAKELISTS  := $(FFTW_BUILD_DIR)/$(FFTW_FULL)/CMakeLists.txt
FFTW_STAGING_DIR := $(STAGING_DIR)/$(FFTW_FULL)
FFTW_INC         := $(FFTW_STAGING_DIR)/usr/local/include/fftw3.h

$(FFTW_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(FFTW_URL)/$(FFTW_FULL).tar.gz -O $@
	touch -c $@

$(FFTW_CMAKELISTS): $(FFTW_TGZ)
	mkdir -p $(FFTW_BUILD_DIR)
	tar xzf $< -C $(FFTW_BUILD_DIR)
	touch -c $@

$(FFTW_INC): $(FFTW_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(FFTW_BUILD_DIR)/$(FFTW_FULL) && \
	LDFLAGS=-lm \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FFTW_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D BUILD_SHARED_LIBS=Off \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D BUILD_TESTS=Off \
		-D ENABLE_OPENMP=On -D ENABLE_THREADS=On -D WITH_COMBINED_THREADS=On \
		-D ENABLE_SSE=On -D ENABLE_SSE2=On -D ENABLE_AVX=On && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release && \
	cmake -S. -Bbuildf \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FFTW_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D BUILD_SHARED_LIBS=Off \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D BUILD_TESTS=Off \
		-D ENABLE_OPENMP=On -D ENABLE_THREADS=On -D WITH_COMBINED_THREADS=On \
		-D ENABLE_FLOAT=On \
		-D ENABLE_SSE=On -D ENABLE_SSE2=On -D ENABLE_AVX=On && \
	cmake --build buildf --config Release -j$(shell nproc) && \
	cmake --install buildf --config Release && \
	cmake -S. -Bbuildl \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FFTW_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D BUILD_SHARED_LIBS=Off \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D BUILD_TESTS=Off \
		-D ENABLE_OPENMP=On -D ENABLE_THREADS=On -D WITH_COMBINED_THREADS=On \
		-D ENABLE_LONG_DOUBLE=On && \
	cmake --build buildl --config Release -j$(shell nproc) && \
	cmake --install buildl --config Release && \
	case $(HOST_TRIPLE) in \
		"aarch64"*) ;; \
		"arm"*) ;; \
		*) cmake -S. -Bbuildq \
			-G "Ninja Multi-Config" \
			-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FFTW_STAGING_DIR)/usr/local \
			-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
			-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
			-D CMAKE_C_COMPILER_LAUNCHER=ccache \
			-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
			-D BUILD_SHARED_LIBS=Off \
			-D CMAKE_POSITION_INDEPENDENT_CODE=On \
			-D BUILD_TESTS=Off \
			-D ENABLE_OPENMP=On -D ENABLE_THREADS=On -D WITH_COMBINED_THREADS=On \
			-D ENABLE_QUAD_PRECISION=On && \
		cmake --build buildq --config Release -j$(shell nproc) && \
		cmake --install buildq --config Release ;; \
	esac
	touch -c $@
	ln -sf $(FFTW_FULL) $(STAGING_DIR)/fftw

fftw: $(FFTW_INC)

.PHONY: fftw

# Eigen
EIGEN_URL         := https://gitlab.com/libeigen/eigen/-/archive
EIGEN_VERSION     := 3.4.0
EIGEN_FULL        := eigen-$(EIGEN_VERSION)
EIGEN_TGZ         := $(DOWNLOAD_DIR)/$(EIGEN_FULL).tar.gz
EIGEN_BUILD_DIR   := $(BUILD_DIR)
EIGEN_CMAKELISTS  := $(EIGEN_BUILD_DIR)/$(EIGEN_FULL)/CMakeLists.txt
EIGEN_STAGING_DIR := $(STAGING_DIR)/$(EIGEN_FULL)
EIGEN_INC         := $(EIGEN_STAGING_DIR)/usr/local/include/eigen3/Eigen/Eigen

$(EIGEN_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(EIGEN_URL)/$(EIGEN_VERSION)/$(EIGEN_FULL).tar.gz -O $@
	touch -c $@

$(EIGEN_CMAKELISTS): $(EIGEN_TGZ)
	mkdir -p $(EIGEN_BUILD_DIR)
	tar xzf $< -C $(EIGEN_BUILD_DIR)
	touch -c $@

$(EIGEN_INC): $(EIGEN_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(EIGEN_BUILD_DIR)/$(EIGEN_FULL) && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(EIGEN_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D EIGEN_BUILD_DOC=Off -D BUILD_TESTING=Off && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf $(EIGEN_FULL) $(STAGING_DIR)/eigen

eigen: $(EIGEN_INC)

.PHONY: eigen

# CasADi
CASADI_URL         := https://github.com/casadi/casadi/archive/refs/tags
CASADI_VERSION     := 3.5.5
CASADI_FULL        := casadi-$(CASADI_VERSION)
CASADI_TGZ         := $(DOWNLOAD_DIR)/$(CASADI_FULL).tar.gz
CASADI_BUILD_DIR   := $(BUILD_DIR)
CASADI_CMAKELISTS  := $(CASADI_BUILD_DIR)/$(CASADI_FULL)/CMakeLists.txt
CASADI_STAGING_DIR := $(STAGING_DIR)/$(CASADI_FULL)
CASADI_INC         := $(CASADI_STAGING_DIR)/usr/local/include/casadi/casadi.hpp

$(CASADI_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(CASADI_URL)/$(CASADI_VERSION).tar.gz -O $@
	touch -c $@

$(CASADI_CMAKELISTS): $(CASADI_TGZ)
	mkdir -p $(CASADI_BUILD_DIR)
	tar xzf $< -C $(CASADI_BUILD_DIR)
	touch -c $@

$(CASADI_INC): $(CASADI_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(CASADI_BUILD_DIR)/$(CASADI_FULL) && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_INSTALL_PREFIX=$(BASE_DIR)/$(CASADI_STAGING_DIR)/usr/local \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(CASADI_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D WITH_COMMON=Off \
		-D WITH_PYTHON=Off \
		-D WITH_PYTHON3=Off \
		-D WITH_OPENMP=Off \
		-D WITH_THREAD=On \
		-D WITH_DL=On \
		-D WITH_IPOPT=Off \
		-D ENABLE_STATIC=On \
		-D ENABLE_SHARED=Off && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf $(CASADI_FULL) $(STAGING_DIR)/casadi

# CasADi's CMake script insists on making installation paths absolute using
# CMAKE_INSTALL_PREFIX :(

casadi: $(CASADI_INC)

.PHONY: casadi

# pybind11
PYBIND11_URL         := https://github.com/pybind/pybind11/archive/refs/tags
PYBIND11_VERSION     := 2.10.1
PYBIND11_FULL        := pybind11-$(PYBIND11_VERSION)
PYBIND11_TGZ         := $(DOWNLOAD_DIR)/$(PYBIND11_FULL).tar.gz
PYBIND11_BUILD_DIR   := $(BUILD_DIR)
PYBIND11_CMAKELISTS  := $(PYBIND11_BUILD_DIR)/$(PYBIND11_FULL)/CMakeLists.txt
PYBIND11_STAGING_DIR := $(STAGING_DIR)/$(PYBIND11_FULL)
PYBIND11_INC         := $(PYBIND11_STAGING_DIR)/usr/local/include/pybind11/pybind11.h

$(PYBIND11_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(PYBIND11_URL)/v$(PYBIND11_VERSION).tar.gz -O $@
	touch -c $@

$(PYBIND11_CMAKELISTS): $(PYBIND11_TGZ)
	mkdir -p $(PYBIND11_BUILD_DIR)
	tar xzf $< -C $(PYBIND11_BUILD_DIR)
	touch -c $@

$(PYBIND11_INC): $(PYBIND11_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(PYBIND11_BUILD_DIR)/$(PYBIND11_FULL) && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(PYBIND11_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D PYBIND11_INSTALL=On -D PYBIND11_TEST=Off -D PYBIND11_NOPYTHON=On && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf $(PYBIND11_FULL) $(STAGING_DIR)/pybind11

pybind11: $(PYBIND11_INC)

.PHONY: pybind11

# Clean
clean:
	rm -rf $(BUILD_DIR) $(PY_STAGING_DIR) $(PYPY_STAGING_DIR) $(CMAKE_DIR) \
		$(FFTW_STAGING_DIR) $(EIGEN_STAGING_DIR) $(CASADI_STAGING_DIR)

clean-toolchain:
	chmod -R +w $(TOOLCHAIN_DIR)/x-tools ||:
	rm -rf $(TOOLCHAIN_DIR)/x-tools
