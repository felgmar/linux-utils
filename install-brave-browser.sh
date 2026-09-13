#!/bin/sh
set -e

BRAVE_REPOFILE="https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo"

sudo dnf config-manager addrepo --from-repofile=$BRAVE_REPOFILE

sudo dnf install -y brave-origin
