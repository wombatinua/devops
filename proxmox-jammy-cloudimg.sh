#!/usr/bin/env bash

VMID=1024
STORAGE="local-nvme"

wget -O jammy-cloud.img https://cloud-images.ubuntu.com/minimal/daily/jammy/current/jammy-minimal-cloudimg-amd64.img

# apt install sudo
# sudo apt update -y
# sudo apt install libguestfs-tools -y

virt-customize -a jammy-cloud.img --update
virt-customize -a jammy-cloud.img --install qemu-guest-agent
virt-customize -a jammy-cloud.img --install rsyslog
virt-customize -a jammy-cloud.img --install fail2ban
virt-customize -a jammy-cloud.img --install mc

virt-customize -a jammy-cloud.img --run-command "sed -i s/^PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config"
virt-customize -a jammy-cloud.img --run-command "cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local"
# virt-customize -a jammy-cloud.img --run-command "systemctl enable fail2ban"

sudo qm create $VMID --name "jammy-cloud" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
sudo qm importdisk $VMID jammy-cloud.img $STORAGE --format qcow2
sudo qm set $VMID --serial0 socket --vga serial0
sudo qm set $VMID --scsihw virtio-scsi-single
sudo qm set $VMID --scsi0 $STORAGE:$VMID/vm-$VMID-disk-0.qcow2,cache=writeback,discard=on,iothread=1
sudo qm disk resize $VMID scsi0 8G

sudo qm set $VMID --ide2 $STORAGE:cloudinit
sudo qm set $VMID --ciuser ubuntu
sudo qm set $VMID --cipassword ubuntu
sudo qm set $VMID --searchdomain local
sudo qm set $VMID --nameserver 1.1.1.1
sudo qm set $VMID --ipconfig0 "ip=dhcp,ip6=auto"

sudo qm set $VMID --onboot 1
sudo qm set $VMID --ostype l26
sudo qm set $VMID --boot c --bootdisk scsi0
sudo qm set $VMID --agent enabled=1,fstrim_cloned_disks=1
sudo qm set $VMID --protection 1

# sudo qm template $VMID
rm -f jammy-cloud.img
