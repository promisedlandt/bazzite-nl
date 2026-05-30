#!/bin/bash

set -ouex pipefail

mkdir /gnu

# Offload directory
mkdir -p /var/gnu/store

# SELinux policy
cp /ctx/guix/guix-daemon.{pp,te} /usr/share/selinux/targeted/
