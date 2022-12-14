import sys
from platform_config import (
    PlatformConfig,
    arch_flags,
    cmake_system_name,
    cmake_system_processor,
    cpack_debian_architecture,
    multiarch_lib_dir,
)

toolchain_contents = """\
# For more information, see 
# https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html,
# https://cmake.org/cmake/help/book/mastering-cmake/chapter/Cross%20Compiling%20With%20CMake.html, and
# https://tttapa.github.io/Pages/Raspberry-Pi/C++-Development-RPiOS/index.html.

# System information
set(CMAKE_SYSTEM_NAME "{CMAKE_SYSTEM_NAME}")
set(CMAKE_SYSTEM_PROCESSOR "{CMAKE_SYSTEM_PROCESSOR}")
set(CROSS_GNU_TRIPLE "{CROSS_GNU_TRIPLE}"
    CACHE STRING "The GNU triple of the toolchain to use")
set(CMAKE_LIBRARY_ARCHITECTURE {CMAKE_LIBRARY_ARCHITECTURE})

# Toolchain
set(TOOLCHAIN_DIR "${{CMAKE_CURRENT_LIST_DIR}}/../x-tools/${{CROSS_GNU_TRIPLE}}")
set(CMAKE_C_COMPILER "${{TOOLCHAIN_DIR}}/bin/${{CROSS_GNU_TRIPLE}}-gcc"
    CACHE FILEPATH "C compiler")
set(CMAKE_CXX_COMPILER "${{TOOLCHAIN_DIR}}/bin/${{CROSS_GNU_TRIPLE}}-g++"
    CACHE FILEPATH "C++ compiler")
set(CMAKE_Fortran_COMPILER "${{TOOLCHAIN_DIR}}/bin/${{CROSS_GNU_TRIPLE}}-gfortran"
    CACHE FILEPATH "Fortran compiler")

# Compiler flags
set(CMAKE_C_FLAGS_INIT       "{ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT     "{ARCH_FLAGS}")
set(CMAKE_Fortran_FLAGS_INIT "{ARCH_FLAGS}")

# Search path configuration
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Packaging
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "{CPACK_DEBIAN_PACKAGE_ARCHITECTURE}")

# Locating Python
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(Python3_VERSION_MAJ_MIN "${{Python3_VERSION_MAJOR}}.${{Python3_VERSION_MINOR}}")
if (Python3_INTERPRETER_ID MATCHES "PyPy")
    set(Python3_PyPy_LIB_VERSION "${{Python3_VERSION_MAJ_MIN}}")
    if (Python3_VERSION_MAJ_MIN VERSION_LESS "3.9")
        set(Python3_PyPy_LIB_VERSION "${{Python3_VERSION_MAJOR}}")
    endif()
    set(PYTHON_STAGING_DIR "${{CMAKE_CURRENT_LIST_DIR}}/../pypy${{Python3_VERSION_MAJ_MIN}}")
    set(Python3_LIBRARY "${{PYTHON_STAGING_DIR}}/bin/libpypy${{Python3_PyPy_LIB_VERSION}}-c.so")
    set(Python3_INCLUDE_DIR "${{PYTHON_STAGING_DIR}}/include/pypy${{Python3_VERSION_MAJ_MIN}}")
    string(REGEX MATCH "([0-9]+)\.([0-9]+).*" _ ${{Python3_PyPy_VERSION}})
    set(PY_BUILD_EXT_SUFFIX ".pypy${{Python3_VERSION_MAJOR}}${{Python3_VERSION_MINOR}}-pp${{CMAKE_MATCH_1}}${{CMAKE_MATCH_2}}-${{CMAKE_SYSTEM_PROCESSOR}}-linux-gnu.so")
else()
    execute_process(COMMAND ${{Python3_EXECUTABLE}}
                        -c "import sys; print(sys.abiflags)"
                    OUTPUT_VARIABLE Python3_VERSION_ABI
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(Python3_VERSION_MAJ_MIN_ABI "${{Python3_VERSION_MAJ_MIN}}${{Python3_VERSION_ABI}}")
    set(PYTHON_STAGING_DIR "${{CMAKE_CURRENT_LIST_DIR}}/../python${{Python3_VERSION_MAJ_MIN}}")
    set(Python3_LIBRARY "${{PYTHON_STAGING_DIR}}/usr/local/lib/libpython${{Python3_VERSION_MAJ_MIN_ABI}}.so")
    set(Python3_INCLUDE_DIR "${{PYTHON_STAGING_DIR}}/usr/local/include/python${{Python3_VERSION_MAJ_MIN_ABI}}")
endif()
list(APPEND CMAKE_FIND_ROOT_PATH "${{PYTHON_STAGING_DIR}}")
"""


def get_cmake_toolchain_file(cfg: PlatformConfig):
    subs = {
        "CMAKE_SYSTEM_PROCESSOR": cmake_system_processor(cfg),
        "CMAKE_SYSTEM_NAME": cmake_system_name(cfg),
        "CROSS_GNU_TRIPLE": str(cfg),
        "CMAKE_LIBRARY_ARCHITECTURE": multiarch_lib_dir(cfg),
        "ARCH_FLAGS": arch_flags(cfg),
        "CPACK_DEBIAN_PACKAGE_ARCHITECTURE": cpack_debian_architecture(cfg),
    }
    return toolchain_contents.format(**subs)


if __name__ == "__main__":
    triple = sys.argv[1]
    outfile = sys.argv[2]
    cfg = PlatformConfig.from_string(triple)
    with open(outfile, "w") as f:
        f.write(get_cmake_toolchain_file(cfg))
