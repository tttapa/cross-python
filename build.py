import dataclasses
from itertools import product
from multiprocessing.pool import Pool
import os
from subprocess import run
import sys
from typing import List, Optional
from platform_config import PlatformConfig

this_dir = os.path.dirname(__file__)


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


platforms = [
    PlatformConfig("x86_64", "centos7", "linux", "gnu"),
    PlatformConfig("aarch64", "rpi3", "linux", "gnu"),
    PlatformConfig("armv8", "rpi3", "linux", "gnueabihf"),
    PlatformConfig("armv6", "rpi", "linux", "gnueabihf"),
]

python_versions = [
    PythonVersion(3, 7, 15),
    PythonVersion(3, 8, 15),
    PythonVersion(3, 9, 15),
    PythonVersion(3, 10, 8),
    PythonVersion(3, 11, 0),
    PythonVersion(3, 12, 0, "a1"),
]


class MakefileBuilder:
    def __init__(self, targets: List[str]):
        self.targets = targets

    def __call__(self, args):
        py, platform = args
        if py.executable is None:
            py.executable = f"python{py.major}.{py.minor}"
        opts = [
            f"HOST_TRIPLE={platform}",
            f"PYTHON_VERSION={py.major}.{py.minor}.{py.patch}",
            f"PYTHON_SUFFIX={py.suffix}",
            f"BUILD_PYTHON={py.executable}",
        ]
        cmd = ["make", "-C", this_dir] + self.targets + opts
        print(cmd)
        run(cmd, check=True)


if __name__ == "__main__":
    with Pool(max(2, os.cpu_count() // 2)) as p:
        p.map(
            MakefileBuilder(["python"]),  #
            product(python_versions, platforms))
        p.map(
            MakefileBuilder(["fftw", "eigen", "casadi"]),
            product([PythonVersion.current_version()], platforms),
        )
