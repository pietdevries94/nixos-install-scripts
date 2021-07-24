#! /usr/bin/env bash

# Script to install NixOS from the Hetzner Cloud NixOS bootable ISO image.
# (tested with Hetzner's `NixOS 20.03 (amd64/minimal)` ISO image).
#
# This script wipes the disk of the server!
#
# Instructions:
#
# 1. Mount the above mentioned ISO image from the Hetzner Cloud GUI
#    and reboot the server into it; do not run the default system (e.g. Ubuntu).
# 2. To be able to SSH straight in (recommended), you must replace hardcoded pubkey
#    further down in the section labelled "Replace this by your SSH pubkey" by you own,
#    and host the modified script way under a URL of your choosing
#    (e.g. gist.github.com with git.io as URL shortener service).
# 3. Run on the server:
#
#       # Replace this URL by your own that has your pubkey in
#       curl -L https://raw.githubusercontent.com/nix-community/nixos-install-scripts/master/hosters/hetzner-cloud/nixos-install-hetzner-cloud.sh | sudo bash
#
#    This will install NixOS and power off the server.
# 4. Unmount the ISO image from the Hetzner Cloud GUI.
# 5. Turn the server back on from the Hetzner Cloud GUI.
#
# To run it from the Hetzner Cloud web terminal without typing it down,
# you can either select it and then middle-click onto the web terminal, (that pastes
# to it), or use `xdotool` (you have e.g. 3 seconds to focus the window):
#
#     sleep 3 && xdotool type --delay 50 'curl YOUR_URL_HERE | sudo bash'
#
# (In the xdotool invocation you may have to replace chars so that
# the right chars appear on the US-English keyboard.)
#
# If you do not replace the pubkey, you'll be running with my pubkey, but you can
# change it afterwards by logging in via the Hetzner Cloud web terminal as `root`
# with empty password.

set -e

# Hetzner Cloud OS images grow the root partition to the size of the local
# disk on first boot. In case the NixOS live ISO is booted immediately on
# first powerup, that does not happen. Thus we need to grow the partition
# by deleting and re-creating it.
sgdisk -d 1 /dev/sda
sgdisk -N 1 /dev/sda
partprobe /dev/sda

mkfs.ext4 -F /dev/sda1 # wipes all data!

mount /dev/sda1 /mnt

nixos-generate-config --root /mnt

# Delete trailing `}` from `configuration.nix` so that we can append more to it.
sed -i -E 's:^\}\s*$::g' /mnt/etc/nixos/configuration.nix

# Extend/override default `configuration.nix`:
echo '
  boot.loader.grub.devices = [ "/dev/sda" ];
  
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
    passwordAuthentication = false;
    challengeResponseAuthentication = false;
    extraConfig = "Compression no";
  };

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [ ./ssh-key.pub ];
  };
}
' >> /mnt/etc/nixos/configuration.nix

echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5htg1Kl8V86xy9UG+p9v3x1jb+Qys9U+XU1Qe3+YKg3I9FKfu68PCLGAz6V1PSW4IFTrRuyBUyhv/B5Yey0D4ZiOUStLIMPIstlaL9bouZVqBskTgpDEbjQLvg7UQ3Nvqh1NuvgBxTmEOohG8G7WTHbyk069hVpRJiwqaNMkylN8Mppr0cnGwrXlJQEE0xgCK23xYkpfvFhEv3PyUYaXgXtX8095x7Wzr5v2UL2Avo3Enj/bPKUcS/Tm3dRFqltyvN9Kn+yqglbn3sQK+IFPgJxiB2aW7XSLIWGF6bZrpLXD8g6WGfUZENIfYJ32SZsorEJQWmf+S1KUwgYaw6MK7jOWVlyePNwIlLYLlj8b6AWAbTyurttNpCigjJHabhRCjpWKKdxOjUpd+dV4Y4wRrgYJoaun+jXaCn/8FBrwcEBCIVtXNxgsvttDxq3ZsneshmZG8I+qKlvLPC1jFSYZ68tm0tLpmZmOo2gJz7ku7Wf5mSq/AarCpB+MkRDcbb4E=' > /mnt/etc/nixos/ssh-key.pub

nixos-install --no-root-passwd

poweroff
