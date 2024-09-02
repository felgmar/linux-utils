#!/usr/bin/env python3

from argparse import ArgumentParser
from sys import platform
from urllib.request import urlretrieve
import datetime
import progressbar

running_os = platform.lower()

parser = ArgumentParser(prog="virtio-win-updater")
group = parser.add_mutually_exclusive_group()

parser.add_argument("-b", "--branch", type=str, help="Override the default branch",
                    default="stable", metavar="", required=False)

parser.add_argument("-d", "--download-directory", type=str, help="Override the default download path",
                    metavar="", required=True)

parser.add_argument("-v", "--verbose", action="store_true", help="Print more messages")

group.add_argument("--version", action="version", version="%(prog)s 1.0")

args = parser.parse_args()

class download_progress():
    def __init__(self):
        self.time: str = "{:%Y%m%d_%H%M%S}".format(datetime.datetime.now())
        self.progress_bar = None

    def __call__(self, block_number: int, block_size: int, total_size: int):
        if self.progress_bar == None:
            self.progress_bar = progressbar.ProgressBar(max_value=total_size)
            self.progress_bar.print(f"Downloading virtio-win-{args.branch}.{self.time}.iso, please wait...")
            self.progress_bar.start()
            
        bytes_recieved: int = block_number * block_size

        if bytes_recieved < total_size:
            self.progress_bar.update(bytes_recieved)
        else:
            self.progress_bar.finish()

def get_virtio_iso(destination_path: str, branch: str):
    main_url: str = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads"
    time: datetime.datetime = "{:%Y%m%d_%H%M%S}".format(datetime.datetime.now())

    match branch:
        case "stable":
            urlretrieve(f"{main_url}/{branch}-virtio/virtio-win.iso", 
                        f"{destination_path}/virtio-win-stable.{time}.iso",
                        reporthook=download_progress())
        case "latest":
            urlretrieve(f"{main_url}/{branch}-virtio/virtio-win.iso",
                        f"{destination_path}/virtio-win-latest.{time}.iso",
                        reporthook=download_progress())
        case _:
            if branch:
                raise ValueError(f"[!] {branch}: invalid branch")
            else:
                raise ValueError(f"[!] no valid branch was specified")

if running_os != "linux":
    raise RuntimeError(f"{platform.lower()}: platform not supported")
else:
        get_virtio_iso(args.download_directory, args.branch)
