#!/bin/bash

VMID=1024
STORAGE="local-nvme"
PACKAGES=("qemu-guest-agent" "fail2ban" "mc")

COMMANDS=(
	"sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf"
	"ufw allow OpenSSH && ufw --force enable"
	"cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
	"systemctl enable fail2ban"
)

wget -O noble-cloud.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

apt install libguestfs-tools dhcpcd-base -y
virt-customize -a noble-cloud.img --update

# install packages
for package in "${PACKAGES[@]}"; do
	virt-customize -a noble-cloud.img --install "$package"
done

# run commands
for command in "${COMMANDS[@]}"; do
	virt-customize -a noble-cloud.img --run-command "$command"
done

# destroy vm
if qm list | grep -q "$VMID "; then
	qm stop $VMID --skiplock
	qm set $VMID --protection 0
	qm destroy $VMID --skiplock
	rm /var/lib/rrdcached/db/pve2-vm/$VMID
fi

# create vm
qm create $VMID --name "noble-cloud" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk $VMID noble-cloud.img $STORAGE --format qcow2
qm set $VMID --description "Ubuntu Noble Cloud ($(date +%d%m%Y%H%M))"
qm set $VMID --serial0 socket #--vga serial0
qm set $VMID --scsihw virtio-scsi-single
qm set $VMID --scsi0 $STORAGE:$VMID/vm-$VMID-disk-0.qcow2,discard=on,iothread=1
qm disk resize $VMID scsi0 8G

# configure vm
qm set $VMID --onboot 1
qm set $VMID --ostype l26
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --agent enabled=1,fstrim_cloned_disks=1
qm set $VMID --protection 1

# configure cloud-init
qm set $VMID --ide0 $STORAGE:cloudinit
qm set $VMID --ciuser ubuntu
qm set $VMID --cipassword ubuntu
qm set $VMID --searchdomain local
qm set $VMID --nameserver 1.1.1.1
qm set $VMID --ciupgrade 0
qm set $VMID --ipconfig0 "ip=dhcp"

rm -f noble-cloud.img
# qm template $VMID
