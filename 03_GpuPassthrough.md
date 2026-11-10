# GPU passthrough

## Remote control host OS
If you got a integrated GPU come with your CPU or motherboard  
then it's good to skip VNC and SSH steps

Otherwise during configuration, your dedicated graphics card will have a time  
that not connecting to host OS but also not connecting to guest OS  
No video, see nothing so can do nothing  
To prevent this setup remote control for host OS  
and connect to it with another tablet or phone

### Setup video remote control in host OS
I used to assume:  
1. XRDP assume nobody will login to physical PC, but KVM for gaming purpose often login locally during setup  
2. Host OS itself may run game directly, cause conflict on local login and remote login at same time

The actual result is:
1. Just don't login to host OS locally, use whatever you want, both doesn't handle things well once login locally happens
2. Host OS never need to run game directly, either run game in Windows guest OS or Linux guest OS

Very important: use `sudo reboot` instead of  
reboot button after connect to VNC desktop environment to make sure reboot is happen  
for unknown reason I find my VNC service just stopped but system reboot didn't happen

#### Pick a VNC software
Server side:  
TightVNC provide only Windows VNC viewer (VNC client)  
TigerVNC winvnc (Windows VNC Server) is currently unmaintained

Client side:  
TigerVNC provide exe download in  
https://sourceforge.net/projects/tigervnc/files/stable/1.16.2/

Paid plan:  
TightVNC has commericial MightyViewer and says  
...our latest Server for Unix/Linux is not available under free GNU GPL license and is not available for public download and review at our web-site.

In general, TigerVNC has Linux server and Windows client  
doesn't ads random commericial thing  
So choose TigerVNC over TightVNC  
https://wiki.archlinux.org/title/TigerVNC

During GPU assign to VM, there is no GPU and monitor  
so choose tigervnc-standalone-server over tigervnc-scraping-server

#### Install VNC
`sudo apt install tigervnc-standalone-server`  
Type VNC password  
`vncpasswd`

`nano $XDG_CONFIG_HOME/tigervnc/config`
```
session=lxqt
geometry=1920x1080
localhost=no
alwaysshared
```
Without this will result in "vnc server quit with error 1"

`session`: I use LXQt, not sure how other desktop environment  
`alwaysshared`: Multiple client connect at same time will see same desktop

Note that port 5900 and 5901 may taken by KVM virtual machine related stuff  
and cause VNC failed to start, check listing port by  
`sudo ss -tulpn | grep "udp\|tcp"`  
If 5901 already taken, use :101 for 6001 port  
This command also can be used to confirm TigerVNC is  
listen at 0.0.0.0 instead of localhost

After pick a port  
`sudo nano /etc/tigervnc/vncserver.users`
```
:101=<your linux system user name>
```
Without this will result in "No user configured for display :1"  
note that there is no space in the line of config

Try start TigerVNC  
`sudo systemctl start tigervncserver@:101.service`  
`sudo systemctl status tigervncserver@:101.service`

If anything goes wrong  
Very important: TigerVNC server log is located at  
`~/.local/state/tigervnc/`  
`sudo systemctl stop tigervncserver@:101.service`  
Read log, do something and  
`sudo systemctl start tigervncserver@:101.service`  
`sudo systemctl status tigervncserver@:101.service`

#### Connect to VNC server
First reboot host OS, then don't login locally to it

On Windows client  
Download stand alone TigerVNC viewer `vncviewer-X.Y.Z.exe`  
Very important, client use full port **6001** instead of :101  
5900+101=6001  
So connect to this address `<ip address>:6001`

TigerVNC use environment variable to autofill password  
`VNC_PASSWORD=<password>`  
There is `VNC_USERNAME=` available but with right server port number it's not needed

ON Linux KDE, environment variable can be set in start menu shortcut  
right click on TigerVNC icon, Edit Application...  
there is Environment variables to type `VNC_PASSWORD=<password>`

Once verified VNC connection is work, set VNC server start on boot  
`sudo systemctl enable tigervncserver@:101.service`

### As final solution, enable ssh text remote control
When it come to graphics and GPU,  
video based remote control may be buggy and corruption  
SSH can provide a reliable way to repair VNC settings  
`sudo apt install openssh-server`  
`sudo nano /etc/ssh/sshd_config`
```
PermitRootLogin no
```
Check config is valid  
`sudo sshd -t`

Restart SSH to apply settings  
`sudo systemctl restart ssh`  
`sudo systemctl status ssh`  
SSH by default listen on port `22`

Test with Windows powershell client  
`ssh <user name>@<domain or ip address>`

If Windows optional feature OpenSSH Client is installed  
but ssh command not available  
Add this path to system environment variable  
`C:\Windows\System32\OpenSSH`

## GPU passthrough  
https://www.youtube.com/watch?v=KVDUs019IB8  
One GPU for multiple virtual machine at same time  
on Nvidia customer graphics card is done by vGPU  
Nvidia doesn't privide vGPU feature for Linux on customer graphics card  
Likely Windows GPU partition can utilize vGPU  
For KVM, one gpu can only assign to one running virtual machine at a time

### Host OS BIOS settings
https://forum.level1techs.com/t/gpu-passthrough-stopped-working-after-bios-update/246850/5  
Run `sudo dmesg | grep IOMMU`  
If you see something like  
"Firmware has requested this device have a 1:1 IOMMU mapping"  
Then you're using a newer BIOS may require to disable  
"Kernel DMA Protection Indicator" for IOMMU to work  
For example, MSI BIOS: OC, Advanced CPU Configuration,  
AMD CBS, IOMMU set to Enabled, Kernel DMA Protection Indicator set to Disabled

### Locate device id
Run command show pcie list  
remember dedicated graphics card device id like `[10de:1b06]`  
Also remember HDMI audio device id lik `10de:10ef`  
`lspci -nn`

Example  
`10de:1b06,10de:10ef`

AMD is `amd_iommu`, I don't what Intel does, maybe check the original video  
https://www.youtube.com/watch?v=KVDUs019IB8  
Add this config to exist `GRUB_CMDLINE_LINUX_DEFAULT`  
`sudo nano /etc/default/grub`
```
GRUB_CMDLINE_LINUX_DEFAULT="<exist config> amd_iommu=on vfio-pci-ids=10de:1b06,10de:10ef"
```
Optional: add `iommu=pt` after `amd_iommu=on`  
this improve performance if you run Linux kernel version 3.10 and later

Optional: if remove `quiet` from exist config  
will allow watch debug message during boot to help fix things on boot fail  
but for me is unnecessary

After grub config done  
`sudo grub-mkconfig -o /boot/grub/grub.cfg`

**From now on, if you don't have integrated GPU  
all command MUST run in remote control session**

Run command show pci list, remember driver name,  
maybe `nvidia`, `nouveau` for "GPU"  
`snd_hda_intel` for "HDMI audio"  
`lspci -k`

`sudo nano /etc/modprobe.d/vfio.conf`
```
options vfio-pci ids=10de:1b06,10de:10ef
softdep <gpu driver name> pre: vfio-pci
softdep <hdmi driver name> pre: vfio-pci
```
`sudo update-initramfs -u`  
`sudo reboot`

Verify driver again, confirm driver is now `vfio-pci`  
`lspci -k`

Once driver confirmed, add GPU and HDMI audio to virtual machine  
as PCI Host Device in Virtual Machine Manager  
I also add my USB mouse and sound card to it directly,  
later in optimize performance section there will be a tutorial  
tells how to pass USB as PCI

If keyboard is not USB but PS/2  
https://unix.stackexchange.com/questions/198736/passthrough-ps-2-keyboard-to-guest-os  
sudo dmesg | grep input  
Locate "AT Translated Set 2 keyboard" and it's path  
`/devices/platform/i8042/serio0/input/input0`

Add a input device in Virtual Machine Manager,  
switch to XML, replace everything with
```
<input type="evdev">
  <source dev="/dev/input/by-path/platform-i8042-serio-0-event-kbd" grab="all" grabToggle="ctrl-ctrl" repeat="on"/>
</input>
```
Get "source dev" path with command  
`ls /dev/input/by-path`  
But usually is just event0 and i8042-serio-0
