#!/usr/bin/env bash

#### Demo Setup for MRMCD2023: Linux Audit Framework - An Introduction ####
#### https://talks.mrmcd.net/2023/talk/VSBRVX/ ####
#### @author: sergej.schmidt[NOSPAM]wallsec.de

SPLUNK_DEB='splunk-9.1.1-64e843ea36b1-linux-2.6-amd64.deb'

if [ ! -e "$SPLUNK_DEB" ]; then
  >&2 echo "[ERROR] File $SPLUNK_DEB not found. Download Splunk testversion and restart script. Maybe change SPLUNK_DEB variable in this script."
  >&2 echo "[ERROR] You'll have to register an account at splunk.com and afterwards, you can fetch it here: https://www.splunk.com/en_us/download/splunk-enterprise.html"
  exit 1
fi


if ! grep bookworm /etc/os-release >/dev/null; then
  >&2 echo "[WARNING]: I am not running on Debian 12 (Bookworm). This script might fail!1!!"
fi

if [ "$EUID" -ne 0 ]; then
  >&2 echo "[ERROR] Run me as root! Bye until then."
  exit 1
fi


# Install Auditd and depencencies
apt install -y auditd curl acl

# Fetch auditd rules from froth and load them
curl -s -o /etc/audit/rules.d/demo_audit.rules "https://raw.githubusercontent.com/Neo23x0/auditd/639bad50ebf0fd8b546b956d1a54d48b681e8698/audit.rules"
augenrules --load

# Install Splunk
apt install -y "./$SPLUNK_DEB"

# Create admin user for webui
splunk_admin_user="victim"
pw="victimvictim"
splunk_admin_pw="$(/opt/splunk/bin/splunk hash-passwd $pw)"
cat <<EOF > /opt/splunk/etc/system/local/user-seed.conf
[user_info]
USERNAME = $splunk_admin_user
HASHED_PASSWORD = $splunk_admin_pw
EOF

/opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk -group splunk --accept-license --answer-yes --no-prompt
systemctl start Splunkd.service

# Change log_group, so Splunk can access Auditd logs
sed -i 's/^log_group.*/log_group\ =\ splunk/g' /etc/audit/auditd.conf

## Setup Laurel
laurel_tar="laurel-v0.5.3-x86_64-musl.tar.gz"
mkdir -p laurel
curl -s -L -o "laurel/$laurel_tar" "https://github.com/threathunters-io/laurel/releases/download/v0.5.3/$laurel_tar"
tar xf "laurel/$laurel_tar" -C laurel
install -m755 laurel/laurel /usr/local/sbin/laurel
chmod 755 /usr/local/sbin/laurel
curl -s -L -o /etc/audit/plugins.d/laurel.conf "https://raw.githubusercontent.com/threathunters-io/laurel/43ac1f86040aa09a7e9c1e3f08b07665a7ce025f/etc/audit/plugins.d/laurel.conf"
mkdir -p /etc/laurel
curl -s -L -o /etc/laurel/config.toml "https://raw.githubusercontent.com/threathunters-io/laurel/43ac1f86040aa09a7e9c1e3f08b07665a7ce025f/etc/laurel/config.toml"
useradd --system --shell /usr/sbin/nologin --home-dir /var/log/laurel --create-home _laurel
systemctl restart auditd

>&2 echo " -------------------- "
>&2 echo "[NOTE] Follow instructions in the slides to add local Auditd and Laurel Logs as a data source into Splunk."
