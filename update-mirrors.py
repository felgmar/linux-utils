#!/usr/bin/env python3

from argparse import ArgumentParser
from getpass import getuser
from sys import platform
from subprocess import run

parser = ArgumentParser(prog="update-mirrors")
parser.add_argument("-d", "--distro", type=str, metavar="", default="arch",
                    help="the distro for which to download mirrors for")
parser.add_argument("-s", "--save", type=str, metavar="", default="/etc/pacman.d/mirrorlist",
                    help="directory where to save the mirrorlist at")
parser.add_argument("--version", action="version", version="%(prog)s 1.0")

args = parser.parse_args()

if __name__ == "__main__":
    current_platform: str = platform.lower()
    current_user: str = getuser()

    if not current_platform == "linux":
        raise RuntimeError(f"{current_platform}: platform not supported")
    else:
        if not current_user == "root":
            raise PermissionError("insufficient permissions to run this script")

        cmd: str = f"/usr/bin/rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist {args.distro}"
        run(args=cmd, shell=True)
