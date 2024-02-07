# Cross-compiled Python

This repository cross-compiles Python itself, as well as some common scientific dependencies for ARMv6, ARMv7, AArch64 and x86-64.  
The intended use case is cross-compiling Python C/C++ extension modules. For this purpose, it integrates well with [py-build-cmake](https://github.com/tttapa/py-build-cmake).

Supported targets are:
- `x86_64-centos7-linux-gnu`: 64-bit Intel or AMD
- `aarch64-rpi3-linux-gnu`: ARMv8 Raspberry Pi with 64-bit operating system (RPi 3, RPi 4)
- `armv8-rpi3-linux-gnueabihf`: ARMv8 Raspberry Pi with 32-bit operating system (RPi 3, RPi 4)
- `armv7-neon-linux-gnueabihf`: Generic ARMv7 with NEON SIMD
- `armv6-rpi-linux-gnueabihf`: ARMv6 Raspberry Pi (RPi, RPi 2, RPi Zero)

The compilers are GCC 13.1.0, built by [crosstool-ng](https://github.com/crosstool-ng/crosstool-ng), and support C, C++ and Fortran.
Using a Clang frontend is also supported (but Clang must be installed separately).

The included libraries are:
- [CPython](https://www.python.org/) 3.7.17, 3.8.18, 3.9.18, 3.10.13, 3.11.8 and 3.12.2
- [pybind11](https://pybind11.readthedocs.io/en/stable/index.html) 2.10.1, 2.11.1, master and [cross](https://github.com/tttapa/pybind11/tree/cross)
- [nanobind](https://nanobind.readthedocs.io/en/latest/) 1.8.0
- [FFTW](https://fftw.org/) 3.3.10
- [Eigen](https://eigen.tuxfamily.org) 3.4.0 and master
- [CasADi](https://web.casadi.org/) 3.6.4
- [GoogleTest](https://github.com/google/googletest) main
- [Flang](https://github.com/llvm/llvm-project/tree/main/flang) 16.0.6
- [OpenBLAS](https://github.com/xianyi/OpenBLAS) 0.3.26
- [MUMPS](https://github.com/coin-or-tools/ThirdParty-Mumps) 5.5.1
- [Ipopt](https://github.com/coin-or/Ipopt) 3.14.14
- [SuiteSparse](https://github.com/DrTimothyAldenDavis/SuiteSparse) 7.6.0

## Typical usage

### CMake

CMake toolchain files are included in `$triple/$triple.toolchain.cmake`, 
e.g. `x86_64-centos7-linux-gnu/x86_64-centos7-linux-gnu.toolchain.cmake`.
The toolchains can be selected by passing the appropriate toolchain file to
CMake when configuring the project, by using the `--toolchain` flag (or
`-DCMAKE_TOOLCHAIN_FILE=` on older versions of CMake).

The included libraries are in `$triple/$name`, e.g.
`x86_64-centos7-linux-gnu/casadi`, and can be passed to CMake using the
`CMAKE_FIND_ROOT_PATH` variable (as a semicolon-separated list). You can also
explicitly set the package directories, e.g.
`-Dcasadi_DIR=x86_64-centos7-linux-gnu/casadi/usr/local/lib/cmake/casadi`.

To use Clang instead of GCC, use `-DTOOLCHAIN_USE_CLANG=On`, and optionally set
the `TOOLCHAIN_CLANG_PREFIX` and `TOOLCHAIN_CLANG_SUFFIX` variables to select
a specific version, e.g. `-DTOOLCHAIN_CLANG_PREFIX=/usr/bin/`
`-DTOOLCHAIN_CLANG_SUFFIX=-15` selects `/usr/bin/clang-15`,
`/usr/bin/clang++-15` and `/usr/bin/flang-new-15` as compilers.

### py-build-cmake

The following script can be used to compile a [py-build-cmake](https://github.com/tttapa/py-build-cmake)
package for many different versions of Python and many different architectures.

```sh
package_path="$PWD"
python_versions=(3.7 3.8 3.9 3.10 3.11)
platforms=(armv6-rpi-linux-gnueabihf armv7-neon-linux-gnueabihf armv8-rpi3-linux-gnueabihf aarch64-rpi3-linux-gnu x86_64-centos7-linux-gnu)

# Download cross-python libraries and toolchains
download_url="https://github.com/tttapa/cross-python/releases/latest/download"
staging_dir="$PWD/python-cross-staging"
mkdir -p "$staging_dir"
for triple in "${platforms[@]}"; do
	if [ ! -d "$staging_dir/$triple" ]; then
		wget "$download_url/full-$triple.tar.xz" -O "full-$triple.tar.xz"
		tar xJf "full-$triple.tar.xz" -C "$staging_dir"
		rm "full-$triple.tar.xz"
	fi
done

# Build the package for Python versions ...
for py_version in "${python_versions[@]}"; do
	python$py_version -m pip install -U pip build
	# ... and for all platforms
	for triple in "${platforms[@]}"; do
		staging="$staging_dir/$triple"
		# Write a configuration file so CMake finds the libraries
		config="$triple.py-build-cmake.config.toml"
		cat <<- EOF > "$config"
		[cmake.options]
		CMAKE_FIND_ROOT_PATH = "$staging/pybind11;$staging/casadi;$staging/eigen;$staging/fftw"
		USE_GLOBAL_PYBIND11 = "On"
		EOF
		# Build the Python package with the right version of Python,
		# pointing py-build-cmake to the right cross-compilation configuration,
		# and using the configuration file with the library paths we just wrote.
		LDFLAGS='-static-libgcc -static-libstdc++' \
		python$py_version -m build "$package_path" \
			-C--cross="$staging/$triple.py-build-cmake.cross.toml" \
			-C--local="$PWD/$config"
	done
done
```

## Cross-compiling yourself

You can of course use this repository to cross-compile the dependencies yourself instead of downloading the pre-built archives:
```sh
triple=x86_64-centos7-linux-gnu
make toolchain HOST_TRIPLE=$triple              # Download the toolchain
python3 build.py --host $triple --py 3.11.8     # Cross-compile Python 3.11
python3 build.py --host $triple --package fftw  # Cross-compile FFTW
```
See `python3 build.py --help` for the available options.

## Toolchains

The custom cross-compilation toolchains are built by [**tttapa/toolchains**](https://github.com/tttapa/toolchains).
