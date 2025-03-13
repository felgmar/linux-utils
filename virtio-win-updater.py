#!/usr/bin/env python3

import argparse, sys, urllib, datetime
import urllib.request

CURRENT_PLATFORM = sys.platform.lower()

parser = argparse.ArgumentParser(prog="virtio-win-updater")
group = parser.add_mutually_exclusive_group()

parser.add_argument("-b", "--branch", type=str, help="Override the default branch",
                    default="stable", metavar="", required=False)

parser.add_argument("-d", "--download-directory", type=str, help="Override the default download path",
                    metavar="", required=True)

parser.add_argument("-v", "--verbose", action="store_true", help="Print more messages")

group.add_argument("--version", action="version", version="%(prog)s 1.0")

args = parser.parse_args()

def get_virtio_iso(destination_path: str, branch: str):
    main_url: str = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads"

    time: str = "{:%Y%m%d_%H%M%S}".format(datetime.datetime.now())

    if destination_path.endswith("/"):
        destination_path = destination_path.removesuffix("/")

    upstream_iso: str = f"{main_url}/{branch}-virtio/virtio-win.iso"
    stable_iso: str = f"{destination_path}/virtio-win-stable_{time}.iso"
    latest_iso: str = f"{destination_path}/virtio-win-latest_{time}.iso"

    match branch:
        case "stable":
            print("Downloading file:", stable_iso)
            try:
                urllib.request.urlretrieve(upstream_iso, stable_iso)
            except Exception as e:
                raise e
        case "latest":
            print("Downloading file:", latest_iso)
            try:
                urllib.request.urlretrieve(upstream_iso, latest_iso)
            except Exception as e:
                raise e
        case _:
            if branch:
                raise ValueError(f"{branch} is not a valid branch")
            else:
                raise ValueError(f"no valid branch was specified")

if __name__ == '__main__':
    if CURRENT_PLATFORM != "linux":
        raise RuntimeError(f"{sys.platform.lower()}: platform not supported")
    else:
        try:
            if args.download_directory.endswith("/"):
                args.download_directory = args.download_directory.removesuffix("/")
            get_virtio_iso(args.download_directory, args.branch)
        except Exception as e:
            raise e
