#!/bin/bash

set -ouex pipefail

### Uninstall packages
dnf5 remove -y Sunshine \
  waydroid

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux \
  chezmoi \
  firefox \
  greetd \
  gtkgreet \
  @cosmic-desktop-environment

# COPRs
dnf5 -y copr enable ublue-os/staging
dnf5 -y copr enable wezfurlong/wezterm-nightly
dnf5 -y install wezterm
# Disable COPRs so they don't end up enabled on the final image:
dnf5 -y copr disable ublue-os/staging
dnf5 -y copr disable wezfurlong/wezterm-nightly

dnf5 -y autoremove

systemctl enable podman.socket

systemctl disable plasmalogin.service
systemctl enable greetd.service

mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/flatpak_preinstall/*.preinstall /etc/flatpak/preinstall.d/

/ctx/guix.sh
