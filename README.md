# Remnawave-MOTD (by distillium)

![screenshot](screenshot.png)

## Installation
1. Delete the default motd
```
sudo rm /etc/update-motd.d/*
```
2. Run the motd install script: 
```
bash <(curl -sSL https://raw.githubusercontent.com/distillium/remnawave-motd/refs/heads/main/install-motd.sh)
```
## Commands

- `rw-motd` — manually display the current MOTD.

- `rw-motd-set` — open a menu to enable/disable MOTD info blocks.
