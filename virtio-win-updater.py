#!/usr/bin/env python3
import argparse, sys, urllib
import shutil
from email.utils import formatdate
from pathlib import Path
from urllib.error import HTTPError
import urllib.request

CURRENT_PLATFORM = sys.platform.lower()

parser = argparse.ArgumentParser(prog="virtio-win-updater")
group = parser.add_mutually_exclusive_group()

parser.add_argument("-b", "--branch", type=str,
                    help="Override the default branch",
                    default="stable", metavar="",
                    choices=["stable", "latest"], required=False)

parser.add_argument("-d", "--download-directory", type=str,
                    help="Set a custom download path.",
                    default="~/Downloads", metavar="", required=False)

parser.add_argument("-v", "--verbose", action="store_true",
                    help="Print more messages")

group.add_argument("--version", action="version", version="%(prog)s 1.0")

args = parser.parse_args()

def retrieve_upstream_content(destination_path: str, upstream_url: str):
    destination = Path(destination_path).expanduser()
    request = urllib.request.Request(upstream_url)

    if destination.exists():
        request.add_header(
            "If-Modified-Since",
            formatdate(destination.stat().st_mtime, usegmt=True),
        )

    try:
        with urllib.request.urlopen(request) as response, destination.open("wb") as output:
            shutil.copyfileobj(response, output)
    except HTTPError as error:
        if error.code == 304:
            print("File is already up to date:", destination)
            return
        raise

def get_virtio_iso(destination_path: str, branch: str):
    main_url: str = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads"

    if destination_path.endswith("/"):
        destination_path = destination_path.removesuffix("/")

    upstream_iso: str = f"{main_url}/{branch}-virtio/virtio-win.iso"
    stable_iso: str = f"{destination_path}/virtio-win-stable.iso"
    latest_iso: str = f"{destination_path}/virtio-win-latest.iso"

    match branch:
        case "stable":
            print("Downloading file:", stable_iso)
            retrieve_upstream_content(stable_iso, upstream_iso)
        case "latest":
            print("Downloading file:", latest_iso)
            retrieve_upstream_content(latest_iso, upstream_iso)
        case _:
            if branch:
                raise ValueError(f"{branch} is not a valid branch")
            else:
                raise ValueError(f"no valid branch was specified")

if __name__ == '__main__':
    if not CURRENT_PLATFORM == "linux":
        raise RuntimeError(f"{sys.platform.lower()}: platform not supported")
    else:
        try:
            if args.download_directory.endswith("/"):
                args.download_directory = args.download_directory.removesuffix("/")
            get_virtio_iso(args.download_directory, args.branch)
        except Exception as e:
            raise e
