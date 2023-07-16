BUILD_TRIPLE    := x86_64-unknown-linux-gnu
HOST_TRIPLE     := armv6-rpi-linux-gnueabihf
PYTHON_VERSION  := 3.10.12
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

# Zlib
ZLIB_URL         := https://zlib.net
ZLIB_VERSION     := 1.2.13
ZLIB_FULL        := zlib-$(ZLIB_VERSION)
ZLIB_TGZ         := $(DOWNLOAD_DIR)/$(ZLIB_FULL).tar.gz
ZLIB_BUILD_DIR   := $(BUILD_DIR)
ZLIB_MAKEFILE    := $(ZLIB_BUILD_DIR)/$(ZLIB_FULL)/Makefile
ZLIB_STAGING_DIR := $(STAGING_DIR)/$(ZLIB_FULL)
ZLIB_INC         := $(ZLIB_STAGING_DIR)/usr/local/include/zlib.h

$(ZLIB_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(ZLIB_URL)/$(ZLIB_FULL).tar.gz -O $@
	touch -c $@

$(ZLIB_MAKEFILE): $(ZLIB_TGZ)
	mkdir -p $(ZLIB_BUILD_DIR)
	tar xzf $< -C $(ZLIB_BUILD_DIR)
	touch -c $@

$(ZLIB_INC): $(ZLIB_MAKEFILE)
	cd $(ZLIB_BUILD_DIR)/$(ZLIB_FULL) && \
	CC="${HOST_TRIPLE}-gcc" \
	LD="${HOST_TRIPLE}-ld" \
	./configure \
		--prefix=$(BASE_DIR)/$(ZLIB_STAGING_DIR)/usr/local && \
	$(MAKE) MAKEFLAGS= && \
	$(MAKE) install MAKEFLAGS=
	ln -sf $(ZLIB_FULL) $(STAGING_DIR)/zlib

zlib: $(ZLIB_INC)

.PHONY: zlib

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

$(PYTHON_MAKEFILE): $(PYTHON_CONFIGURE) $(ZLIB_INC)
	cd $(PY_BUILD_DIR)/$(PYTHON_FULL) && \
	{ [ ! -e setup.py ] || \
		sed -i 's@# Debian/Ubuntu multiarch support.@return@g' setup.py; } && \
	CONFIG_SITE="$(BASE_DIR)/config.site" \
	ZLIB_CFLAGS="-I $(BASE_DIR)/$(ZLIB_STAGING_DIR)/usr/local/include" \
	ZLIB_LIBS="-L $(BASE_DIR)/$(ZLIB_STAGING_DIR)/usr/local/lib -lz" \
	./configure \
		--enable-ipv6 \
		--enable-shared \
		--disable-test-modules \
		--build="$(BUILD_TRIPLE)" \
		--host="$(HOST_TRIPLE)" \
		--prefix="/usr/local" \
		--with-pkg-config=no \
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
PYPY_VERSION     := 7.3.12
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

# Eigen
EIGEN_MASTER_URL         := https://gitlab.com/libeigen/eigen/-/archive
EIGEN_MASTER_VERSION     := master
EIGEN_MASTER_FULL        := eigen-$(EIGEN_MASTER_VERSION)
EIGEN_MASTER_TGZ         := $(DOWNLOAD_DIR)/$(EIGEN_MASTER_FULL).tar.gz
EIGEN_MASTER_BUILD_DIR   := $(BUILD_DIR)
EIGEN_MASTER_CMAKELISTS  := $(EIGEN_MASTER_BUILD_DIR)/$(EIGEN_MASTER_FULL)/CMakeLists.txt
EIGEN_MASTER_STAGING_DIR := $(STAGING_DIR)/$(EIGEN_MASTER_FULL)
EIGEN_MASTER_INC         := $(EIGEN_MASTER_STAGING_DIR)/usr/local/include/eigen3/Eigen/Eigen

$(EIGEN_MASTER_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(EIGEN_MASTER_URL)/$(EIGEN_MASTER_VERSION)/$(EIGEN_MASTER_FULL).tar.gz -O $@
	touch -c $@

$(EIGEN_MASTER_CMAKELISTS): $(EIGEN_MASTER_TGZ)
	mkdir -p $(EIGEN_MASTER_BUILD_DIR)
	tar xzf $< -C $(EIGEN_MASTER_BUILD_DIR)
	touch -c $@

$(EIGEN_MASTER_INC): $(EIGEN_MASTER_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(EIGEN_MASTER_BUILD_DIR)/$(EIGEN_MASTER_FULL) && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(EIGEN_MASTER_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D EIGEN_MASTER_BUILD_DOC=Off -D BUILD_TESTING=Off && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@

eigen-master: $(EIGEN_MASTER_INC)

.PHONY: eigen-master

# GTest
GTEST_URL         := https://github.com/google/googletest/archive/refs/heads
GTEST_VERSION     := main
GTEST_FULL        := googletest-$(GTEST_VERSION)
GTEST_TGZ         := $(DOWNLOAD_DIR)/$(GTEST_FULL).tar.gz
GTEST_BUILD_DIR   := $(BUILD_DIR)
GTEST_CMAKELISTS  := $(GTEST_BUILD_DIR)/$(GTEST_FULL)/CMakeLists.txt
GTEST_STAGING_DIR := $(STAGING_DIR)/$(GTEST_FULL)
GTEST_INC         := $(GTEST_STAGING_DIR)/usr/local/include/gtest/gtest.h

$(GTEST_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(GTEST_URL)/$(GTEST_VERSION).tar.gz -O $@
	touch -c $@

$(GTEST_CMAKELISTS): $(GTEST_TGZ)
	mkdir -p $(GTEST_BUILD_DIR)
	tar xzf $< -C $(GTEST_BUILD_DIR)
	touch -c $@

$(GTEST_INC): $(GTEST_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(GTEST_BUILD_DIR)/$(GTEST_FULL) && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(GTEST_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf $(GTEST_FULL) $(STAGING_DIR)/googletest

googletest: $(GTEST_INC)

.PHONY: googletest

# CasADi
CASADI_URL         := https://github.com/casadi/casadi/archive/refs/tags
CASADI_VERSION     := 3.6.3
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

# nanobind
NANOBIND_URL         := https://github.com/wjakob/nanobind
NANOBIND_VERSION     := 1.4.0
NANOBIND_FULL        := nanobind-$(NANOBIND_VERSION)
NANOBIND_STAGING_DIR := $(STAGING_DIR)/$(NANOBIND_FULL)
NANOBIND_SHARE_DIR   := $(NANOBIND_STAGING_DIR)/usr/local/share
NANOBIND_CONFIG      := $(NANOBIND_SHARE_DIR)/nanobind/cmake/nanobind-config.cmake

$(NANOBIND_CONFIG):
	rm -rf $(NANOBIND_STAGING_DIR)
	mkdir -p $(NANOBIND_SHARE_DIR)
	git clone $(NANOBIND_URL) --branch v$(NANOBIND_VERSION) \
		$(NANOBIND_SHARE_DIR)/nanobind --recursive --single-branch --depth=1
	touch -c $@
	ln -sf $(NANOBIND_FULL) $(STAGING_DIR)/nanobind

nanobind: $(NANOBIND_CONFIG)

.PHONY: nanobind

# Flang runtime
FLANG_URL         := https://github.com/llvm/llvm-project/archive/refs/tags
FLANG_VERSION     := 16.0.6
FLANG_FULL        := flang-$(FLANG_VERSION)
FLANG_TGZ         := $(DOWNLOAD_DIR)/$(FLANG_FULL).tar.gz
FLANG_BUILD_DIR   := $(BUILD_DIR)
FLANG_CMAKELISTS  := $(FLANG_BUILD_DIR)/llvm-project-llvmorg-$(FLANG_VERSION)/flang/CMakeLists.txt
FLANG_STAGING_DIR := $(STAGING_DIR)/$(FLANG_FULL)
FLANG_LIB         := $(FLANG_STAGING_DIR)/usr/local/lib/libFortran_main.a

$(FLANG_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(FLANG_URL)/llvmorg-$(FLANG_VERSION).tar.gz -O $@
	touch -c $@

$(FLANG_CMAKELISTS): $(FLANG_TGZ)
	mkdir -p $(FLANG_BUILD_DIR)
	tar xzf $< -C $(FLANG_BUILD_DIR)
	touch -c $@

$(FLANG_LIB): $(FLANG_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(FLANG_BUILD_DIR)/llvm-project-llvmorg-$(FLANG_VERSION)/flang/runtime && \
	CXXFLAGS="-Wno-error=narrowing" \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FLANG_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	cd $(FLANG_BUILD_DIR)/llvm-project-llvmorg-$(FLANG_VERSION)/flang/lib/Decimal && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(FLANG_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf $(FLANG_FULL) $(STAGING_DIR)/flang

flang: $(FLANG_LIB)

.PHONY: flang

# OpenBLAS
OpenBLAS_URL         := https://github.com/xianyi/OpenBLAS/archive/refs/tags
OpenBLAS_VERSION     := 0.3.21
OpenBLAS_FULL        := OpenBLAS-$(OpenBLAS_VERSION)
OpenBLAS_TGZ         := $(DOWNLOAD_DIR)/$(OpenBLAS_FULL).tar.gz
OpenBLAS_BUILD_DIR   := $(BUILD_DIR)
OpenBLAS_CMAKELISTS  := $(OpenBLAS_BUILD_DIR)/$(OpenBLAS_FULL)/CMakeLists.txt
OpenBLAS_STAGING_DIR := $(STAGING_DIR)/openblas-$(OpenBLAS_VERSION)
OpenBLAS_INC         := $(OpenBLAS_STAGING_DIR)/usr/local/include/openblas/lapack.h

$(OpenBLAS_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(OpenBLAS_URL)/v$(OpenBLAS_VERSION).tar.gz -O $@
	touch -c $@

$(OpenBLAS_CMAKELISTS): $(OpenBLAS_TGZ)
	mkdir -p $(OpenBLAS_BUILD_DIR)
	tar xzf $< -C $(OpenBLAS_BUILD_DIR)
	cd $(OpenBLAS_BUILD_DIR)/$(OpenBLAS_FULL) && \
	wget -O- https://github.com/tttapa/OpenBLAS/commit/f6ad97738475152f90353638b9d4a7eb50d5ccfe.patch | \
	patch cmake/prebuild.cmake
	touch -c $@

$(OpenBLAS_INC): $(OpenBLAS_CMAKELISTS) $(CMAKE_TOOLCHAIN)
	cd $(OpenBLAS_BUILD_DIR)/$(OpenBLAS_FULL) && \
	case $(HOST_TRIPLE) in \
		"x86_64"*) target="HASWELL" ;; \
		"aarch64"*) target="ARMV8" ;; \
		"armv8"*) target="ARMV7" ;; \
		"armv7"*) target="ARMV7" ;; \
		"armv6"*) target="ARMV6" ;; \
		*) target="" ;; \
	esac && \
	cmake -S. -Bbuild \
		-G "Ninja Multi-Config" \
		-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(OpenBLAS_STAGING_DIR)/usr/local \
		-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
		-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
		-D CMAKE_C_COMPILER_LAUNCHER=ccache \
		-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-D BUILD_SHARED_LIBS=Off \
		-D BUILD_STATIC_LIBS=On \
		-D CMAKE_POSITION_INDEPENDENT_CODE=On \
		-D TARGET="$$target" && \
	cmake --build build --config Release -j$(shell nproc) && \
	cmake --install build --config Release
	touch -c $@
	ln -sf openblas-$(OpenBLAS_VERSION) $(STAGING_DIR)/openblas

openblas: $(OpenBLAS_INC)

.PHONY: openblas

# MUMPS
MUMPS_URL         := https://github.com/coin-or-tools/ThirdParty-Mumps/archive/refs/tags/releases
MUMPS_VERSION     := 3.0.4
MUMPS_FULL        := ThirdParty-Mumps-releases-$(MUMPS_VERSION)
MUMPS_TGZ         := $(DOWNLOAD_DIR)/$(MUMPS_FULL).tar.gz
MUMPS_BUILD_DIR   := $(BUILD_DIR)
MUMPS_CONFIGURE   := $(MUMPS_BUILD_DIR)/$(MUMPS_FULL)/configure
MUMPS_STAGING_DIR := $(STAGING_DIR)/mumps-$(MUMPS_VERSION)
MUMPS_STAGING_PFX := $(MUMPS_STAGING_DIR)/usr/local
MUMPS_INC         := $(MUMPS_STAGING_PFX)/include/coin-or/mumps/dmumps_c.h
MUMPS_PC          := $(MUMPS_STAGING_PFX)/lib/pkgconfig/coinmumps.pc

$(MUMPS_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(MUMPS_URL)/$(MUMPS_VERSION).tar.gz -O $@
	touch -c $@

$(MUMPS_CONFIGURE): $(MUMPS_TGZ)
	mkdir -p $(MUMPS_BUILD_DIR)
	tar xzf $< -C $(MUMPS_BUILD_DIR)
	touch -c $@

$(MUMPS_INC): $(MUMPS_CONFIGURE) $(OpenBLAS_INC)
	cd $(MUMPS_BUILD_DIR)/$(MUMPS_FULL) && \
	./get.Mumps && \
	CC="ccache $(HOST_TRIPLE)-gcc" \
	FC="ccache $(HOST_TRIPLE)-gfortran" \
	CFLAGS="-DNDEBUG -O3" \
	CXXFLAGS="-DNDEBUG -O3" \
	FCFLAGS="-O3" \
	./configure \
		--prefix="$(BASE_DIR)/$(MUMPS_STAGING_DIR)/usr/local" \
		--with-lapack="-L$(BASE_DIR)/$(OpenBLAS_STAGING_DIR)/usr/local/lib -lopenblas -pthread -lm" \
		--enable-static \
		--disable-shared \
		--host="$(HOST_TRIPLE)" && \
	$(MAKE) MAKEFLAGS= && \
	$(MAKE) install MAKEFLAGS=
	sed -i "s@$(BASE_DIR)/$(STAGING_DIR)@\$${pcfiledir}/../../../../..@g" $(MUMPS_PC)
	touch -c $@
	ln -sf mumps-$(MUMPS_VERSION) $(STAGING_DIR)/mumps

mumps: $(MUMPS_INC)

.PHONY: mumps

# Ipopt
Ipopt_URL         := https://github.com/coin-or/Ipopt/archive/refs/tags/releases
Ipopt_VERSION     := 3.14.12
Ipopt_FULL        := Ipopt-releases-$(Ipopt_VERSION)
Ipopt_TGZ         := $(DOWNLOAD_DIR)/$(Ipopt_FULL).tar.gz
Ipopt_BUILD_DIR   := $(BUILD_DIR)
Ipopt_CONFIGURE   := $(Ipopt_BUILD_DIR)/$(Ipopt_FULL)/configure
Ipopt_STAGING_DIR := $(STAGING_DIR)/ipopt-$(Ipopt_VERSION)
Ipopt_STAGING_PFX := $(Ipopt_STAGING_DIR)/usr/local
Ipopt_INC         := $(Ipopt_STAGING_PFX)/include/coin-or/IpoptConfig.h
Ipopt_PC          := $(Ipopt_STAGING_PFX)/lib/pkgconfig/ipopt.pc

$(Ipopt_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(Ipopt_URL)/$(Ipopt_VERSION).tar.gz -O $@
	touch -c $@

$(Ipopt_CONFIGURE): $(Ipopt_TGZ)
	mkdir -p $(Ipopt_BUILD_DIR)
	tar xzf $< -C $(Ipopt_BUILD_DIR)
	touch -c $@

$(Ipopt_INC): $(Ipopt_CONFIGURE) $(MUMPS_INC)
	cd $(Ipopt_BUILD_DIR)/$(Ipopt_FULL) && \
	CC="ccache $(HOST_TRIPLE)-gcc" \
	CXX="ccache $(HOST_TRIPLE)-g++" \
	FC="ccache $(HOST_TRIPLE)-gfortran" \
	CFLAGS="-DNDEBUG -O3" \
	CXXFLAGS="-DNDEBUG -O3" \
	FCFLAGS="-O3" \
	./configure \
		--prefix="$(BASE_DIR)/$(Ipopt_STAGING_DIR)/usr/local" \
		--with-lapack="-L$(BASE_DIR)/$(OpenBLAS_STAGING_DIR)/usr/local/lib -lopenblas -pthread -lm" \
		--with-mumps \
		--with-mumps-lflags="-L$(BASE_DIR)/$(MUMPS_STAGING_DIR)/usr/local/lib -lcoinmumps -lgfortran" \
		--with-mumps-cflags="-I$(BASE_DIR)/$(MUMPS_STAGING_DIR)/usr/local/include/coin-or/mumps" \
		--enable-static \
		--disable-shared \
		--host="$(HOST_TRIPLE)" && \
	$(MAKE) MAKEFLAGS=-j$(shell nproc) && \
	$(MAKE) install MAKEFLAGS=
	sed -i "s@$(BASE_DIR)/$(STAGING_DIR)@\$${pcfiledir}/../../../../..@g" $(Ipopt_PC)
	touch -c $@
	ln -sf ipopt-$(Ipopt_VERSION) $(STAGING_DIR)/ipopt

ipopt: $(Ipopt_INC)

.PHONY: ipopt

# SuiteSparse
SuiteSparse_URL         := https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/refs/tags
SuiteSparse_VERSION     := 7.1.0
SuiteSparse_FULL        := SuiteSparse-$(SuiteSparse_VERSION)
SuiteSparse_TGZ         := $(DOWNLOAD_DIR)/$(SuiteSparse_FULL).tar.gz
SuiteSparse_BUILD_DIR   := $(BUILD_DIR)
SuiteSparse_MAKEFILE    := $(SuiteSparse_BUILD_DIR)/$(SuiteSparse_FULL)/Makefile
SuiteSparse_STAGING_DIR := $(STAGING_DIR)/suitesparse-$(SuiteSparse_VERSION)
SuiteSparse_INC         := $(SuiteSparse_STAGING_DIR)/usr/local/include/SuiteSparse_config.h

$(SuiteSparse_TGZ):
	mkdir -p $(DOWNLOAD_DIR)
	wget $(SuiteSparse_URL)/v$(SuiteSparse_VERSION).tar.gz -O $@
	touch -c $@

$(SuiteSparse_MAKEFILE): $(SuiteSparse_TGZ)
	mkdir -p $(SuiteSparse_BUILD_DIR)
	tar xzf $< -C $(SuiteSparse_BUILD_DIR)
	touch -c $@

$(SuiteSparse_INC): $(SuiteSparse_MAKEFILE) $(OpenBLAS_INC) $(CMAKE_TOOLCHAIN)
	for lib in SuiteSparse_config Mongoose AMD BTF CAMD CCOLAMD COLAMD CHOLMOD CSparse CXSparse LDL KLU UMFPACK RBio SuiteSparse_GPURuntime GPUQREngine SPQR; do \
		cd $(BASE_DIR)/$(SuiteSparse_BUILD_DIR)/$(SuiteSparse_FULL)/$$lib && \
		cmake -S. -Bbuild \
			-G "Ninja Multi-Config" \
			-D CMAKE_STAGING_PREFIX=$(BASE_DIR)/$(SuiteSparse_STAGING_DIR)/usr/local \
			-D CMAKE_TOOLCHAIN_FILE=$(BASE_DIR)/$(CMAKE_TOOLCHAIN) \
			-D CMAKE_FIND_ROOT_PATH=$(BASE_DIR)/$(OpenBLAS_STAGING_DIR)/usr/local \
			-D Python3_EXECUTABLE=$(shell which $(BUILD_PYTHON)) \
			-D CMAKE_C_COMPILER_LAUNCHER=ccache \
			-D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
			-D BUILD_SHARED_LIBS=Off \
			-D CMAKE_POSITION_INDEPENDENT_CODE=On && \
		cmake --build build --config Release -j$(shell nproc) && \
		cmake --install build --config Release; \
		status=$$?; \
		if [ $$status -ne 0 ]; then exit $$status; fi \
	done
	touch -c $@
	ln -sf suitesparse-$(SuiteSparse_VERSION) $(STAGING_DIR)/suitesparse
	cp $(SuiteSparse_BUILD_DIR)/$(SuiteSparse_FULL)/LICENSE.txt $(STAGING_DIR)/suitesparse-$(SuiteSparse_VERSION)

suitesparse: $(SuiteSparse_INC)

.PHONY: suitesparse

# Clean
clean:
	rm -rf $(BUILD_DIR) $(PY_STAGING_DIR) $(PYPY_STAGING_DIR) $(CMAKE_DIR) \
		$(FFTW_STAGING_DIR) $(EIGEN_STAGING_DIR) $(EIGEN_MASTER_STAGING_DIR) \
		$(CASADI_STAGING_DIR) $(FLANG_STAGING_DIR) $(OpenBLAS_STAGING_DIR) \
		$(MUMPS_STAGING_DIR) $(Ipopt_STAGING_DIR) $(SuiteSparse_STAGING_DIR)

clean-toolchain:
	chmod -R +w $(TOOLCHAIN_DIR)/x-tools ||:
	rm -rf $(TOOLCHAIN_DIR)/x-tools
