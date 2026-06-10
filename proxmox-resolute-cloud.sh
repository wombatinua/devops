#!/bin/bash
set -euo pipefail

RELEASE="resolute"
STORAGE="local-nvme"
RESIZE="8G"
VMID=1024

PACKAGES=("qemu-guest-agent" "fail2ban" "mc")

COMMANDS=(
	"sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
	"ufw allow OpenSSH && ufw --force enable"
	"cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
	"systemctl enable qemu-guest-agent"
	"systemctl enable fail2ban"
	"truncate -s 0 /etc/machine-id"
	"rm -f /var/lib/dbus/machine-id"
	"cloud-init clean --logs || true"
)

IMAGE="https://cloud-images.ubuntu.com/${RELEASE}/current/${RELEASE}-server-cloudimg-amd64.img"

apt install libguestfs-tools dhcpcd-base -y
[[ -f "${RELEASE}-cloud.img" ]] || wget -O "${RELEASE}-cloud.img" "$IMAGE"

RUN_COMMAND_ARGS=()
for cmd in "${COMMANDS[@]}"; do
	RUN_COMMAND_ARGS+=(--run-command "$cmd")
done

virt-customize -a "${RELEASE}-cloud.img" --install "$(IFS=,; echo "${PACKAGES[*]}")" "${RUN_COMMAND_ARGS[@]}"

if qm list | grep -q "^ *$VMID "; then
	qm stop "$VMID" --skiplock || true
	qm set "$VMID" --protection 0 || true
	qm destroy "$VMID" --skiplock
	rm -rf "/var/lib/rrdcached/db/pve2-vm/$VMID" || true
fi

qm create "$VMID" --name "${RELEASE}-cloud" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk "$VMID" "${RELEASE}-cloud.img" "$STORAGE" --format qcow2 >/dev/null

qm set "$VMID" \
	--description "Ubuntu ${RELEASE^} Cloud ($(date +%d%m%Y%H%M))" \
	--serial0 socket \
	--vga serial0 \
	--scsihw virtio-scsi-single \
	--scsi0 "$STORAGE:$VMID/vm-$VMID-disk-0.qcow2,discard=on,iothread=1" \
	--onboot 1 \
	--ostype l26 \
	--boot c \
	--bootdisk scsi0 \
	--agent enabled=1,fstrim_cloned_disks=1 \
	--protection 1 \
	--ide0 "$STORAGE:cloudinit" \
	--ciuser ubuntu \
	--cipassword ubuntu \
	--searchdomain local \
	--nameserver 1.1.1.1 \
	--ciupgrade 0 \
	--ipconfig0 "ip=dhcp"

qm resize "$VMID" scsi0 "$RESIZE"
