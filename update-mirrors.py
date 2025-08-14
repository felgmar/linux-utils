#!/usr/bin/env python3

if __name__ == "__main__":
    from argparse import ArgumentParser
    from getpass import getuser
    from sys import platform
    from subprocess import run
    from os import path

    VALID_DISTROS: list[str] = [ "arch" ]
    SAVE_DIRECTORY: list[str] = [ "/etc/pacman.d/mirrorlist" ]
    CURRENT_PLATFORM: str = platform.lower()
    CURRENT_USER: str = getuser()

    if not CURRENT_PLATFORM == "linux":
        raise RuntimeError(f"{CURRENT_PLATFORM} is not supported")

    if not CURRENT_USER == "root":
        raise PermissionError("you don't have enough permissions to run this script")

    parser = ArgumentParser(prog="update-mirrors",
                            description="Update mirror lists for Linux distributions")
    parser.add_argument("-d", "--distro",
                        type=str,
                        metavar="",
                        default="arch",
                        choices=VALID_DISTROS,
                        help="the distribution for which to setup mirrors" +
                        f" (supported: {', '.join(VALID_DISTROS)})")
    parser.add_argument("-s", "--save",
                        type=str,
                        metavar="",
                        default="/etc/pacman.d/mirrorlist",
                        choices=SAVE_DIRECTORY,
                        help="directory where the mirror list will be saved to" +
                        f" (supported: {', '.join(SAVE_DIRECTORY)})")
    parser.add_argument("--version",
                        action="version",
                        version="%(prog)s 1.0")
    args = parser.parse_args()

    if not args.save in SAVE_DIRECTORY:
        raise FileNotFoundError(f"{args.save} is not a valid save directory")

    if not path.isfile(args.save):
        raise FileNotFoundError(f"{args.save} does not exist")

    CMD: str = f"rate-mirrors --allow-root --save {args.save} {args.distro}"

    try:
        run(args=CMD, shell=True)
    except Exception as e:
        raise e
