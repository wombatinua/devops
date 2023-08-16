#!/usr/bin/env bash

VMID=1024
STORAGE="local-nvme"
PACKAGES=("qemu-guest-agent" "rsyslog" "fail2ban" "ufw" "mc")
COMMANDS=(
	"sed -i s/^PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config"
	"ufw allow OpenSSH && ufw --force enable"
	"cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
	"systemctl enable fail2ban"
)

wget -O jammy-cloud.img https://cloud-images.ubuntu.com/minimal/daily/jammy/current/jammy-minimal-cloudimg-amd64.img

# apt update -y && apt install libguestfs-tools -y

virt-customize -a jammy-cloud.img --update
#virt-customize -a jammy-cloud.img --install qemu-guest-agent
#virt-customize -a jammy-cloud.img --install rsyslog
#virt-customize -a jammy-cloud.img --install fail2ban
#virt-customize -a jammy-cloud.img --install ufw
#virt-customize -a jammy-cloud.img --install mc

for package in "${PACKAGES[@]}"; do
	virt-customize -a jammy-cloud.img --install "$package"
done

#virt-customize -a jammy-cloud.img --run-command "sed -i s/^PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config"
#virt-customize -a jammy-cloud.img --run-command "ufw allow OpenSSH && ufw --force enable"
#virt-customize -a jammy-cloud.img --run-command "cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
#virt-customize -a jammy-cloud.img --run-command "systemctl enable fail2ban"

for command in "${COMMANDS[@]}"; do
	virt-customize -a jammy-cloud.img --run-command "$command"
done

if qm list | grep -q "$VMID "; then
	qm stop $VMID --skiplock
	qm set $VMID --protection 0
	qm destroy $VMID --skiplock
	rm /var/lib/rrdcached/db/pve2-vm/$VMID
fi

qm create $VMID --name "jammy-cloud" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk $VMID jammy-cloud.img $STORAGE --format qcow2
qm set $VMID --description "Ubuntu Jammy Cloud ($(date +%d%m%Y%H%M))"
qm set $VMID --serial0 socket --vga serial0
qm set $VMID --scsihw virtio-scsi-single
qm set $VMID --scsi0 $STORAGE:$VMID/vm-$VMID-disk-0.qcow2,cache=writeback,discard=on,iothread=1
qm disk resize $VMID scsi0 8G

qm set $VMID --ide2 $STORAGE:cloudinit
qm set $VMID --ciuser ubuntu
qm set $VMID --cipassword ubuntu
qm set $VMID --searchdomain local
qm set $VMID --nameserver 1.1.1.1
qm set $VMID --ciupgrade 1
qm set $VMID --ipconfig0 "ip=dhcp,ip6=auto"

qm set $VMID --onboot 1
qm set $VMID --ostype l26
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --agent enabled=1,fstrim_cloned_disks=1
qm set $VMID --protection 1

# qm template $VMID
rm -f jammy-cloud.img
