#!/bin/bash

set -ouex pipefail

# Since the top level directory is read only, create an offload directory at /var/gnu and mount it to /gnu
mkdir /gnu
mkdir -p /var/gnu

cp /ctx/guix/gnu.mount /etc/systemd/system
