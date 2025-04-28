#!/usr/bin/env python3

from argparse import ArgumentParser
from getpass import getuser
from sys import platform
from subprocess import run
from os import path

parser = ArgumentParser(prog="update-mirrors")
parser.add_argument("-d", "--distro", type=str, metavar="", default="arch",
                    help="the distro for which to download mirrors for")
parser.add_argument("-s", "--save", type=str, metavar="", default="/etc/pacman.d/mirrorlist",
                    help="directory where the mirror list will be saved to")
parser.add_argument("--version", action="version", version="%(prog)s 1.0")

args = parser.parse_args()

if __name__ == "__main__":
    CURRENT_PLATFORM: str = platform.lower()
    CURRENT_USER: str = getuser()

    if not CURRENT_PLATFORM == "linux":
        raise RuntimeError(f"{CURRENT_PLATFORM} is not supported")
    
    if not CURRENT_USER == "root":
        raise PermissionError("you don't have enough permissions to run this script")

    if not path.isfile(args.save):
        raise FileNotFoundError(f"{args.save} does not exist")

    cmd: str = f"rate-mirrors --allow-root --save {args.save} {args.distro}"
    run(args=cmd, shell=True)
