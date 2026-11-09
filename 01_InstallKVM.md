## Install KVM
The fact is, you don't install KVM

Choose debian 13 as host OS
https://wiki.debian.org/KVM

`sudo apt install qemu-system libvirt-daemon-system`  
`sudo adduser <your username> libvirt`

`sudo apt install virt-manager`

Open "Virtual Machine Manager" from start menu  
File, New Virtual Machine, and the rest is GUI

## Hibernate virtual machine on shutdown

### Use config files for all VM
`sudo nano /etc/default/libvirt-guests`
```
ON_SHUTDOWN=suspend
```
Reboot to apply

### Hibernate some, shutdown others
https://serverfault.com/questions/941535/systemd-running-custom-vm-shutdown-script-before-the-standard-libvirt-guests-s

Write your own shutdown scripts to call `virsh` commands  
Virtual machine but still running after script down will be hibernate  
`nano kvm-shutdown-action.sh`

I do have one if you don't write your own  
check `Tools\toggle\toggle.sh` and it's `README.md`

Run script on shutdown but before hibernate  
`sudo nano /etc/systemd/system/kvm-shutdown-action.service`
```
[Unit]
Description=Run on shutdown
Requires=network-online.target
After=libvirt-guests.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=/path/to/your/shutdown/script/<your shutdown script>
User=root

[Install]
WantedBy=multi-user.target
```
`sudo systemctl enable kvm-shutdown-action.service`
