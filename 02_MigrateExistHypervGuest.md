# Migrate exist Hyper-V guest

## About fstab
After you join Linux world  
Soon you'll meet how to mount your drive to a folder on boot automatically  
The devil, fstab, may cause you not to boot  
these are top things to know about fstab

Mount point can have space in path, replace space with `\040`
```
...
UUID=<uuid>	/home/<username>/Mount/A\040128\040GB\040SSD	...
```

Reload fstab after edit (apply changes)  
`sudo mount -a`  
`sudo systemctl daemon-reload`

After edit fstab, before reboot or shutdown  
YOU MUST run `sudo mount -a` to ENSURE there is no error in fstab file  
Once you forgot to do that and failed to boot  
you may find you can't enter recovery mode because of "root account is locked"

Fine, this is because recent Linux by default suggest not set root password  
but use sudo for high permission operation  
fstab is the one fails you and require recovery mode to fix  
and recovery mode require root password to enter

To fix fstab without root password  
when gurb interface appears, press "E" to temp edit boot argument  
Find the linux line
```
...
linux ...
...
```
Move cursor to linux line, append  
` single init=/bin/bash`  
to exist boot argument, it may look like `"quiet"` or `""`  
for example, `"quiet single init=/bin/bash"`  
Then press F10 or Ctrl+X to boot, this keyboard shortcut is a hint at bottom of screen

When you see command line `#`, type  
`mount -o remount,rw /`  
That add rw to current mount options of root mount point to allow edit system file  
Now you can finally fix fstab by  
`nano /etc/fstab`  
`mount -a`

## About qcow2 file format

### "On-disk" size
ext4 doesn't count "File size" in disk used space but only count "On-disk" size  
But on ntfs3 mounted NTFS drive, disk used space does count "File size"  
So you can't have dynamic expand KVM virtual disk (.qcow2 file) on NTFS partition  
place them in ext4 partition for it to actually dynamic expand

Store disk file in ext4 partition instead of NTFS, Linux can't do fsck or chkdsk to fix NTFS  
When it comes to `/etc/fstab`  
mounted NTFS partition will have dirty bit if not shutdown correctly  
may fail to mount on boot and risk in Linux system not boot  
so it's not reliable to mount NTFS on boot with fstab

You can just use same file system that your Linux system installer does to your system parition  
for store your KVM virtual disk without ever think about it,  
like debian use ext4, fedora use btrfs

### Disk and Controller settings
https://chrisirwin.ca/posts/discard-with-kvm-2020/  
https://chrisirwin.ca/posts/discard-with-kvm/  
https://dustymabe.com/2013/06/11/recover-space-from-vm-disk-images-by-using-discardfstrim/  

Linux usually has built in driver support for default VirtIO Disk or VirtIO SCSI  
If guest OS is **Windows** and previously run on Hyper-V  
I'll use VirtIO SCSI controller for qcow2 disk files in the end  
but at the beginning only add disk to **SATA** controller  
later in optimize performance section there will be a tutorial  
tells how to install driver and change to VirtIO SCSI controller

In Virtual Machine Manager,  
when adding disk, set Cache Mode to "none", Discard mode to "unmap"  
Add detect_zeros unmap to disk XML to prevent "File size" grow on write zero behavior  
Add rotation rate tell guest OS this is SSD  
It will looks like
```
  <driver name="qemu" type="qcow2" cache="none" discard="unmap" detect_zeroes="unmap"/>
  <target dev="sda" bus="scsi" rotation_rate="1"/>
```

### Convert exist vhdx file and reduce file size
Convert vhdx to qcow2  
`qemu-img convert -p -f vhdx -O qcow2 "<source.vhdx>" "<output.qcow2>"`

To shrink a exist disk, use virt-sparsify  
`sudo apt install libguestfs-tools`

Full scan, make disk image as small as possible  
this is safer than in place on sudden power outage  
TMPDIR must be an absolute path to have enouth space  
`mkdir Temp`  
`TMPDIR="$(pwd)/Temp" virt-sparsify "<input_disk.qcow2>" "<output_disk.qcow2>"`

In place, run without create new file in TMPDIR  
Watchout power outage!!! But sometimes you have no choice to not own a big disk  
`virt-sparsify --in-place "<disk file>"`

The tool may slow on certain disk file, in that case run with `sudo`

Don't create a too big dynamic disk like 2 TB but only create small partition of it like 256 GB  
a full shrink require empty space larger than 2 TB  
Create small disk and grow on need in future is more suitable

You can combine them together, cd to a large working directory,  
then use `Tools/convertDisk/convertDisk.sh`

After done sparse, once these files are need to copy between drives  
use argument to keep sparse instead of take full space  
`cp ... --sparse=always`

Default permission of virt-manager created file is  
`sudo chown root:root <disk file.qcow2>`  
`sudo chmod 600 <disk file.qcow2>`

### Disk order
Disk order in device manager is configured by
```
  <target dev=...
```
sda:0, sdb:1, sdc:2, etc

Also, in
```
  <address...controller...bus...target...
```
"unit=" is to specify controller port number,  
like how SATA 0, SATA 1 on motherboard  
can be verify in "Controller SCSI" or "Controller VirtIO SCSI"  
usually sda will be unit 0, sdb will be unit 1, etc

### Linux zero free
In Linux guest OS, create largest possible zero file  
and delete it to make fstrim know empty space to release  
`cd /path/to/a/folder/inside/target/drive`  
`dd if=/dev/zero of=zeroemptyspace bs=1M count=$(df --output=avail -m . | tail -n 1) & rm zeroemptyspace`  
`sudo fstrim -av`

## Pass physical disk to VM
Use this command find disk id, pass by id instead of sda, sdb path, is more reliable  
`lsblk -o ID-LINK,NAME,SIZE,MOUNTPOINT`

When adding to guest VM on Virtual Machine Manager GUI,  
for gpt drive, type "gpt" as Format, instead of auto, auto default is dos (mbr)  
To assign whole disk instead of by partition  
You can select by partition first, then remove partition number in the end  
Or type path directly to "Select or create custom storage" like  
`/dev/disk/by-id/<id>`

Note that use "Browse Local" instead of add path to pool  
once it goes to pool it lose `by-id` and become something like `sda`  
You may be able to go to `/dev/disk/by-id`  
then drag `by-id` from address bar to left panel,  
this should add bookmark depending on your desktop environment,  
So you don't have to browse to that location each time  
just go to folder by bookmark and paste ID-LINK directly to address bar and hit enter

For NVME disk, PCIe passthrough without any configuration is possible  
seems it doesn't require complex setup like how graphics card passthrough

## Virtual machine BIOS settings

### Disable Secure Boot

#### Windows
If you migrating a Windows system before boot with EFI with Secure Boot turned off  
Press any key and enter BIOS settings menu  
Device Manager, Secure Boot Configuration,  
Attempt Secure Boot, Press Space toggle, after confirm ESC back to main menu,  
Reset to reboot without Secure Boot

#### Linux
For Linux, by default Virtual Machine Manager use BIOS  
the only chance to change BIOS to UEFI is "Custom hardware before installation"

Select UEFI x86_64 for 64 bit
- UEFI: Default to OVMF_CODE_4M.ms.fd
- OVMF_CODE_4M.ms.fd: Microsoft Secure Boot, mainly for Windows
- OVMF_CODE_4M.secboot.fd: Unknown, looks like Secure Boot enabled
- OVMF_CODE_4M.fd: EFI boot without Secure Boot

Very important: Most Linux require disable Secure Boot  
But these XML settings **can't** be adjust to "no" after VM created  
so select OVMF_CODE_4M.fd at the beginning for Linux
```
    <firmware>
      <feature enabled="yes" name="enrolled-keys"/>
      <feature enabled="yes" name="secure-boot"/>
    </firmware>
```

### Add boot options on need
Set boot order in Virtual Machine Manager is not enought for some BIOS  
(choosed UEFI or OVMF_CODE_4M.fd)

Type exit and enter in EFI shell to open settings  
Boot Maintenance Manager > Boot Options > Add Boot Option > Select EFI file  
Usually is EFI/debian/grubx64.efi, stored at first patition like "`...HD(1,GPT...`"  
Add description: debian  
Commit Changes and Exit  
Esc back to main page, Reset

## Bridge network
In Linux share a physical network adapter between host and guest  
and let them do IP configuration their own like ethernet cable plugged in  
is bridge a interface, means real interface remains empty  
and assign bridge interface to both host OS and guest OS

Run on host OS  
`sudo apt install bridge-utils`  
`sudo nano /etc/network/interfaces`
```
# Move ip configuration from physical interface to bridge interface
# Comment out lines related to physical interface
#allow-hotplug enp11s0
#iface enp11s0 inet manual
#iface enp11s0 inet6 manual

# Bridge interface
# Use auto because bridge network doesn't auto connect like physical interface when using allow-hotplug
auto br0
iface br0 inet dhcp
	bridge_ports enp11s0
	bridge_stp off
	bridge_fd 0
	bridge_maxwait 0
iface br0 inet6 auto
```
`sudo systemctl restart networking.service`  
or just `sudo reboot`

The above example use DHCP, for static IP configuration  
Important: **don't** set MTU manually on br0 even if it's for host networking,  
must be default for example 1500  
Otherwise virtual machine guest will be limited by value set on host br0 without knowing it!  
If not 1500 it will cause bug in some applications: https://github.com/FreeRDP/FreeRDP/issues/13828#issuecomment-6336470413
```
iface br0 inet static
	address 192.168.1.10
	gateway 192.168.1.1
	netmask 255.255.255.0
	bridge_ports enp11s0
	bridge_stp off
	bridge_fd 0
	bridge_maxwait 0
iface br0 inet6 auto
```

## Interface name

### Linux guest OS bring back eth0
Debian installed with Hyper-V have interface name eth0  
but gone in kvm and become other name format  
Exist network related config and service won't work anymore because of that

Get MAC address by `ip addr`, then  
`sudo nano /etc/systemd/network/10-custom-net.link`
```
[Match]
MACAddress=aa:bb:cc:dd:ee:ff

[Link]
Name=eth0
```
To rename multiple interface, use another file name like  
`sudo nano /etc/systemd/network/<11>-custom-net.link`

Reboot to apply  
`sudo reboot`

If use nftables and your exist config file failed on boot  
Edit service file to let it run after eth0 has added  
Confirm nftables service file location  
`sudo systemctl status nftables.service`  
`sudo nano /lib/systemd/system/nftables.service`
```
[Unit]
Requires=sys-subsystem-net-devices-<your eth0>.device
After=sys-subsystem-net-devices-<your eth0>.device
Requires=sys-subsystem-net-devices-<your eth1...>.device
After=sys-subsystem-net-devices-<your eth1...>.device
```
`sudo reboot`  
Confirm after reboot nftables is now `active (exited)` instead of `failed`  
`sudo systemctl status nftables`

### Windows bring back Ethernet
If can't rename network back to Ethernet  
https://stackoverflow.com/questions/42220423/registry-mismatch-get-netadapter

In the Device-Manager -> show hidden devices -> uninstall all adapters which no longer  connected to the system anymore.
