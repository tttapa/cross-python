import argparse
import dataclasses
from itertools import product
from multiprocessing.pool import Pool
import os
import re
from subprocess import run
import sys
import sysconfig
from typing import List, Optional
from platform_config import PlatformConfig
from pathlib import Path

this_dir = Path(__file__).parent


@dataclasses.dataclass
class PythonVersion:
    major: int
    minor: int
    patch: int
    suffix: str = ""
    executable: Optional[str] = None

    @classmethod
    def current_version(cls):
        v = sys.version_info
        suffix = {
            "alpha": f"a{v.serial}",
            "beta": f"b{v.serial}",
            "candidate": f"rc{v.serial}",
            "final": "",
        }[v.releaselevel]
        return cls(v.major, v.minor, v.micro, suffix, sys.executable)

    @classmethod
    def from_string(cls, s: str):
        m = re.match(r'^(\d+).(\d+).(\d+)((?:a|b|rc)\d+)?$', s)
        return cls(*m.groups(default=""))


DEF_PLATFORMS = [
    PlatformConfig("x86_64", "centos7", "linux", "gnu"),
    PlatformConfig("aarch64", "rpi3", "linux", "gnu"),
    PlatformConfig("armv8", "rpi3", "linux", "gnueabihf"),
    PlatformConfig("armv7", "neon", "linux", "gnueabihf"),
    PlatformConfig("armv6", "rpi", "linux", "gnueabihf"),
]

DEF_PYTHON_VERSIONS = [
    PythonVersion(3, 7, 16),
    PythonVersion(3, 8, 16),
    PythonVersion(3, 9, 16),
    PythonVersion(3, 10, 9),
    PythonVersion(3, 11, 1),
    # PythonVersion(3, 12, 0, "a3"),
]

DEF_PYPY_VERSIONS = [
    PythonVersion(3, 8, 99),
    PythonVersion(3, 9, 99),
]

def is_pypy_platform(plat: PlatformConfig):
    return plat.cpu in ('x86_64', 'aarch64')

DEF_PACKAGES = [
    "py-build-cmake",
    "pybind11",
    "fftw",
    "eigen",
    "eigen-master",
    "googletest",
    "casadi",
]


class MakefileBuilder:
    def __init__(self, build_triple: str, targets: List[str]):
        self.build_triple = build_triple
        self.targets = targets

    def __call__(self, args):
        py, platform = args
        if py.executable is None:
            py.executable = f"python{py.major}.{py.minor}"
        opts = [
            f"BUILD_TRIPLE={self.build_triple}",
            f"HOST_TRIPLE={platform}",
            f"PYTHON_VERSION={py.major}.{py.minor}.{py.patch}",
            f"PYTHON_SUFFIX={py.suffix}",
            f"BUILD_PYTHON={py.executable}",
        ]
        cmd = ["make", "-C", str(this_dir)] + self.targets + opts
        print(cmd)
        run(cmd, check=True)


def main():
    parser = argparse.ArgumentParser(
        description="cross Python builder",
        allow_abbrev=False,
    )
    parser.add_argument(
        "--build",
        type=str,
        default=sysconfig.get_config_var('HOST_GNU_TYPE'),
        help="GNU triple for the build machine",
    )
    parser.add_argument(
        "--host",
        type=str,
        action='append',
        help="GNU triples for the host machines",
    )
    parser.add_argument(
        "--jobs",
        "-j",
        type=int,
        default=1,
        help="Number of parallel jobs",
    )
    parser.add_argument(
        "--python",
        "--py",
        type=str,
        nargs='?',
        action='append',
        help="Python versions to build",
    )
    parser.add_argument(
        "--pypy",
        type=str,
        nargs='?',
        action='append',
        help="PyPy versions to install",
    )
    parser.add_argument(
        "--package",
        "-p",
        type=str,
        nargs='?',
        action='append',
        help="Packages to build",
    )
    args = parser.parse_args()
    if args.python is None and args.package is None and args.pypy is None:
        args.python = [None]
        args.package = [None]

    platforms = DEF_PLATFORMS
    if args.host:
        platforms = list(map(PlatformConfig.from_string, args.host))

    python_versions = None
    if args.python == [None]:
        python_versions = DEF_PYTHON_VERSIONS
    elif args.python:
        python_versions = list(map(PythonVersion.from_string, args.python))

    pypy_versions = None
    if args.pypy == [None]:
        pypy_versions = DEF_PYPY_VERSIONS
    elif args.pypy:
        pypy_versions = list(map(PythonVersion.from_string, args.pypy))

    packages = None
    if args.package == [None]:
        packages = DEF_PACKAGES
    elif args.package:
        packages = args.package

    jobs = args.jobs if args.jobs > 0 else max(1, os.cpu_count() // 2)

    with Pool(jobs) as p:
        if python_versions:
            p.map(
                MakefileBuilder(args.build, ["python"]),
                product(python_versions, platforms),
            )
        if pypy_versions:
            p.map(
                MakefileBuilder(args.build, ["pypy"]),
                product(pypy_versions, filter(is_pypy_platform, platforms)),
            )
        if packages:
            p.map(
                MakefileBuilder(args.build, packages),
                product([PythonVersion.current_version()], platforms),
            )


if __name__ == "__main__":
    main()
