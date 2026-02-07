#!/bin/bash

set -ouex pipefail

# Offload directory
mkdir -p /var/gnu/store

ln -s /var/gnu /

mkdir -p /etc/systemd/system/gnu-store.mount.d
cp /ctx/etc/systemd/system/gnu-store.mount.d/override.conf /etc/systemd/system/gnu-store.mount.d

groupadd --system guix-daemon
useradd -g guix-daemon -G "guix-daemon"	\
  -d /var/empty -s "$(command -v nologin)"	\
  -c "Unprivileged Guix Daemon User" --system guix-daemon

tmp_path="$(mktemp -t -d guix.XXXXXX)"

# Filter version and architecture from the available files
bin_ver_ls=("$(wget "https://ftpmirror.gnu.org/gnu/guix/" --no-verbose -O- \
    | sed -n -e 's/.*guix-binary-\([0-9.]*[a-z0-9]*\)\..*.tar.xz.*/\1/p' \
    | sort -Vu)")

latest_ver="$(echo "${bin_ver_ls[0]}" \
                    | grep -oE "([0-9]{1,2}\.){2}[0-9]{1,2}[a-z0-9]*" \
                    | tail -n1)"

guix_filename="guix-binary-${latest_ver}.x86_64-linux.tar.xz"

wget -P "$tmp_path" \
  "https://ftpmirror.gnu.org/gnu/guix/${guix_filename}"

cd "$tmp_path"

# Extract the store not to /gnu/store, since that will be read-only.
# Instead, extract to /var/gnu/store, which will be bind mounted to /gnu/store by systemd
tar --extract --file "${guix_filename}" -C /var/gnu/store --strip-components=3 --wildcards-match-slash --wildcards "*./gnu/*"

# Extract /var files
tar --extract --file "${guix_filename}" -C / --strip-components=1  --wildcards-match-slash --wildcards "*./var/*"

# TODO create ~root/.config/guix (not available at build time, /var/roothome after)

#ln -sf /var/guix/profiles/per-user/root/current-guix \
    #~root/.config/guix/current

chown -R guix-daemon:guix-daemon /var/gnu/store /var/guix

# The unprivileged daemon cannot create the log directory by itself.
mkdir -p /var/log/guix
chown guix-daemon:guix-daemon /var/log/guix
chmod 755 /var/log/guix

profile_dir=$(find -H /gnu/store/ -type d -name "*-profile")

# Install SELinux policy
#semodule -i "${profile_dir}/share/selinux/guix-daemon.cil"
#restorecon -R /var/gnu/store /var/guix

# Copy systemd files
cp "${profile_dir}/lib/systemd/system/guix-daemon.service" /etc/systemd/system/
cp "${profile_dir}/lib/systemd/system/gnu-store.mount" /etc/systemd/system/

cat <<"EOF" > /etc/profile.d/zzz-guix.sh
# Explicitly initialize XDG base directory variables to ease compatibility
# with Guix System: see <https://issues.guix.gnu.org/56050#3>.
export XCURSOR_PATH="${XCURSOR_PATH:-$HOME/.local/share/icons:$HOME/.icons:/usr/local/share/icons:/usr/share/icons}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
# no default for XDG_RUNTIME_DIR (depends on foreign distro for semantics)

# `guix pull` profile
GUIX_PROFILE="$HOME/.config/guix/current"
export PATH="$GUIX_PROFILE/bin${PATH:+:}$PATH"
# Add to INFOPATH and MANPATH so the latest Guix documentation is available to
# info and man readers.  When INFOPATH is unset, add a trailing colon so Emacs
# searches 'Info-default-directory-list'.  When MANPATH is unset, add a
# trailing colon so the system default search path is used.
export INFOPATH="$GUIX_PROFILE/share/info:${INFOPATH:-}"
export MANPATH="$GUIX_PROFILE/share/man:${MANPATH:-}"

# User's default profile, if it exists
GUIX_PROFILE="$HOME/.guix-profile"
if [ -L "$GUIX_PROFILE" ]; then
  . "$GUIX_PROFILE/etc/profile"

  # see info '(guix) Application Setup'
  export GUIX_LOCPATH="$GUIX_PROFILE/lib/locale${GUIX_LOCPATH:+:}$GUIX_LOCPATH"

  # Documentation search paths may be handled by $GUIX_PROFILE/etc/profile if
  # the user installs info and man readers via Guix.  If the user doesn’t,
  # explicitly add to them so documentation for software from ‘guix install’
  # is available to the system info and man readers.
  case $INFOPATH in
    *$GUIX_PROFILE/share/info*) ;;
    *) export INFOPATH="$GUIX_PROFILE/share/info:$INFOPATH" ;;
  esac
  case $MANPATH in
    *$GUIX_PROFILE/share/man*) ;;
    *) export MANPATH="$GUIX_PROFILE/share/man:$MANPATH"
  esac

  case $XDG_DATA_DIRS in
    *$GUIX_PROFILE/share*) ;;
    *) export XDG_DATA_DIRS="$GUIX_PROFILE/share:$XDG_DATA_DIRS"
  esac
fi

# NOTE: Guix Home handles its own profile initialization in ~/.profile. See
# info '(guix) Configuring the Shell'.

# Clean up after ourselves.
unset GUIX_PROFILE
EOF
