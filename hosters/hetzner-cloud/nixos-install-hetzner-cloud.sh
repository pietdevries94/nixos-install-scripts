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

echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOU03D5oDPOgzBdy6irxnk5M7rhJjJlVy9AI7AhME2LAun/L5FRJ8jp+ip+iE2jcXtT/MsM83EMQkfXQg98Mo13ryjvPCL4glk81V9h6nLXPt0a5+0j2f5xEq/7cXfUh4cKCt9J3RZU2uY/63hJWET5DKMy0ZnhhHA7AqGgZLyrxfC/0UKaW4TwburUnuWZqE1FWHFu2up9f+GGsSa6P2zdtK/ChI0bWhjDZNYQwrX4c06liHvndR1imjVf7UoHetKeu7uYz5X+TkMDZeP+rTsBkshQeIZEMUgGMYeFZSN0RgRSBINKFms/8ny1g6yev6k7g/7WulsJK6Vb/r0lnQNVHdTdQE5NkBYWWZuit1koCRvNZyjSLE5ROPdo+fSN0qpu7GTbftL/DJqVgsEqGCwKXNB7hhHw3OUT7zgnDIEUkhDSpu0Svs3A8c34ulhI05gLKfRXprJY42xQQsEGK60R09FdvNqHWXm1acN3t1tpS6LPkaAkENGhrrdVBeb3QBHz5/JoiBaXFH+6sZfzx1z5g4uu7X0rSmAbvOwl8Y6QfbfiXRZy/PbRryNswIxI5T46vjjHZqlcTHsRYyJAK7jLXEZudQvuHvhacugbuMtrfDlH5VF2s9q4c8rnOI2ra6O1bitIhdp2bW/nZXx5x6CsZUG3/m7nar46dT570NNSw== piet@devries.tech' > /mnt/etc/nixos/ssh-key.pub

nixos-install --no-root-passwd

poweroff
