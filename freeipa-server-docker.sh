#!/bin/bash

# cpu=host

sed -i 's/^GRUB_CMDLINE_LINUX=".*"/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
update-grub
reboot

mkdir -p /opt/docker/freeipa-server/data
cd /opt/docker/freeipa-server

cat <<YAML > compose.yaml
version: '3.8'
services:
  freeipa-server:
    image: freeipa/freeipa-server:rocky-9
    container_name: freeipa-server
    hostname: ipa.domain.local
    read_only: true
    restart: always
    sysctls:
      - net.ipv6.conf.all.disable_ipv6=0
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /opt/docker/freeipa-server/data:/data:Z
    tmpfs:
      - /var/log/journal
      - /run
      - /tmp
    environment:
      - IPA_SERVER_IP=10.10.1.1
    network_mode: bridge
    ports:
      - '80:80'
      - '443:443'
      - '389:389'
      - '636:636'
      - '88:88'
      - '88:88/udp'
      - '464:464'
      - '464:464/udp'
      - '123:123/udp'
YAML

# interactive ipa-server-install
docker compose run --rm freeipa-server
docker compose up -d

# join client
# apt install freeipa-client
# ipa-client-install --force-join --mkhomedir --debug
