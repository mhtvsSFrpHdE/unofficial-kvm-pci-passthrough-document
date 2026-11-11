# Linux gaming

## Steam OS and NVME emulation

### Install Steam OS
It turns out Steam OS doesn't have KVM graphics driver by default  
and just blackscreen after install  
Unless you have AMD GPU passthrough, don't try it  
You don't stand a chance to manual install graphics card driver  
instead read next section to install alternative system  
I'll go with latest Fedora and manually install desktop with wayland

The following are what I try to install SteamOS  
the install is success, but system can't run, no display driver

If you upgrade to testing in order to try Steam OS  
and regretted in the end and remove testing source  
to try do downgrade back to debian 13 trixie  
you may have to live with aptitude for the rest of your life LOL

Steam OS is hard coded to install to `/dev/nvme0n1`  
So add disk to controller like VirtIO SCSI, SATA won't work  
Try it yourself before enable testing,  
Steam OS may update in future to support SATA or VirtIO SCSI

According to https://github.com/virt-manager/virt-manager/discussions/732  
libvirt added NVME emulation in 11.5.0 but currently debian 13 provides 11.3.0  
and Virtual Machine manager is 5.0.0 which is pretty new to support nvme by using XML

Verify libvirt version by  
`virsh version`
If yours newer or is 11.5.0 or newer,  
skip "apt testing" section and add settings directly in Virtual Machine Manager

`sudo nano /etc/apt/sources.list`
```
# Testing, libnss-libvirt
deb http://deb.debian.org/debian testing main contrib non-free
```
`sudo apt update`  
`sudo apt install libnss-libvirt/testing`  
`sudo reboot`

https://github.com/virt-manager/virt-manager/issues/790  
https://libvirt.org/formatdomain.html#controllers  
After reboot, add a controller in Virtual Machine Manager  
and replace everything in XML  
Click on Apply will generate address line
```
<controller type="nvme" index="0">
  <serial>BHYVE-NVME0-01234</serial>
</controller>
```
About serial number:  
https://gitlab.com/libvirt/libvirt/-/blob/master/NEWS.rst?ref_type=heads&plain=1#L98
```
  * bhyve: allow setting disk serial numbers

    The bhyve driver now allows specifying ``<serial>`` for SATA disks and NVMe
    controllers::

      <disk type='file'>
        <serial>BHYVE-SER01-0001</serial>
        <driver name='file' type='raw'/>
        <source file='/tmp/freebsd1.img'/>
        <target dev='hda' bus='sata' rotation_rate='7200'/>
      </disk>
      <controller type='nvme' index='0'>
        <serial>BHYVE-NVME0-01234</serial>
      </controller>

    It also supports specifying ``<wwn>`` for NVMe disks::

      <disk type='file'>
        <driver name='file' type='raw'/>
        <source file='/path/to/some.img'/>
        <target dev='nvme0n1' bus='nvme'/>
        <wwn>01000000efbeadde</wwn>
      </disk>
```

Then add your disk to install Steam OS as regular VirtIO driver,  
edit XML set target
```
<target dev='nvme0n1' bus='nvme'/>
```
Remove exist address line and apply to generate one

Boot device with Steam installation media as USB  
and it should allow install now  
After install, UEFI may require add description,  
check "Linux BIOS: Add boot options on need"  
Find "...HD1,GPT...","efi","steamos","steamcl.efi"  
you can just name it debian  
Also try change boot order move debian to front of EFI shell

### If I don't want Steam OS anymore
Revert to old version debian 13 libvirt  
`sudo nano /etc/apt/sources.list`  
Remove testing source from file

`sudo apt update`  
`sudo apt install aptitude`  
`sudo aptitude install qemu-system/trixie libvirt-daemon-system/trixie virt-manager/trixie`  
Check if qemu-system, libvirt-daemon,  
virt-manager is going to install from provided solution  
(debian 13 is trixie)  
and nothing is going to remove, for example I type "n" just once  
Keep aptitide, you're going to need it at any time in future

Reinstall meta package to fill "optional" dependencies  
`sudo apt remove qemu-system libvirt-daemon-system virt-manager`  
`sudo apt install qemu-system libvirt-daemon-system virt-manager`

## Fedora with KDE wayland
For unknown reason grub will hang  
on press ender during wait for 5s to boot timer...  
press other key has no issue, I'll just ignore it

https://fedoraproject.org/misc  
Pick Fedora Everything iso to install without default desktop environment  
After install and login on text screen

It turns out Steam client runs fine under KDE,  
but with LXQt is full of bug, unusable

Confirm kde package name  
`sudo dnf group info "kde"`  
`sudo dnf group install kde-desktop`  
`sudo systemctl set-default graphical.target`  
`systemctl enable --now plasmalogin.service`

Login to KDE, verify is using wayland  
If not, you may want to do something about it  
`echo $XDG_SESSION_TYPE`

Install Nvidia graphics  
Shutdown and add GPU passthrough, boot with gpu

https://github.com/fady-saied/Nvidia-Fedora-Guide  
`sudo dnf install firefox`  
So you have browser and clipboard access inside virtual machine

`sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm`  
Skip steps of "Secure Boot key enrollment"  
in case using KVM without Secure Boot

Confirm Nvidia GPU detected in system  
`sudo dnf install pciutils`  
`lspci | grep -iE 'VGA|3D|nvidia'`

Install driver, I'm on 1080 Ti Pascal,  
you may have other, check Nvidia-Fedora-Guide document link above  
`sudo dnf install xorg-x11-drv-nvidia-580xx akmod-nvidia-580xx`  
`sudo dnf install xorg-x11-drv-nvidia-580xx-cuda`

Wait for driver auto install, confirm complete with command  
`modinfo -F version nvidia`  
If print version number then it's done,  
if not but says "modinfo: ERROR: Module nvidia not found"  
Keep waiting and be patience,  
you can use qps to watch if something is using CPU or disk

After version number print, reboot and verify GPU is hot  
`sudo reboot`  
`nvidia-smi`

You may also need "Optimize Performance" document after everything done

### Fedora LXQt
https://discussion.fedoraproject.org/t/need-pointers-to-set-up-a-minimalistic-lxqt-on-my-machine/75896/3  
Optional, I installed LXQt and give up  
this one use less RAM but doesn't work with Steam Client or Firefox

The question is  
Firefox doesn't have minimum or maximum button on title bar

After login to LXQt desktop, Steam menu won't open  
Look at Steam tray icon, right click on it and choose Settings  
Go to Interface, there is settings  
"Enable context menu focus compatibility mode"  
and settings to turn off GPU usage on GUI,  
but none of them fix this issue

Steam Big Picture mode not go full screen
1. Right click on tray icon choose Big Picture Mode
2. In big picture mode Settings, Display, Turn on Windowed
3. Enter big picture mode again, click on maximum on title bar
4. Right click on task bar, Configure Panel, Turn on Auto-hide, Uncheck Visible thin margin for hidden panel

Or use big picture mode with Windowed and do maximum,  
it doesn't fullscreen but big enough

Install LXQt, assume I don't have any desktop environment installed  
`sudo dnf group info "lxqt" | less`  
Press Up key and locate group name "lxqt-desktop"  
Press Q exit less mode, press Ctrl+C to reset bash shell  
`sudo dnf group install lxqt-desktop`  
`sudo systemctl set-default graphical.target`  
`sudo reboot`  
After reboot choose Session on login screen for LXQt

Uninstall LXQt  
`sudo dnf group remove lxqt-desktop`  
`sudo dnf autoremove`  
Track colored text, delete config files that can't be removed automatically

Set systemctl back to default text mode  
skip this if other desktop environment is installed  
`sudo systemctl set-default multi-user.target`

Delete lxqt files inside home directory  
https://lxqt-project.org/wiki/General.html  
`sudo rm -rf /etc/xdg/lxqt-qtxdg.conf/`  
`sudo rm -rf /etc/xdg/lxqt/panel.conf`  
`sudo rm -rf /usr/share/lxqt/`  
`sudo rm -rf ~/.config/lxqt/`

PCManFM-Qt  
`sudo rm -rf ~/.config/pcmanfm-qt/lxqt/`  
`sudo rm -rf ~/.local/share/file-manager/actions/`

Pavucontrol-Qt  
`sudo rm -rf ~/.config/pavucontrol-qt/`

LXImage-Qt  
`sudo rm -rf ~/.config/lximage-qt/`

QTerminal  
`sudo rm -rf ~/.config/qterminal.org/`

LXQt-Archiver  
`sudo rm -rf ~/.config/lxqt/archiver.conf`

ScreenGrab  
`sudo rm -rf ~/.config/screengrab/`

Qps  
`sudo rm -rf ~/.config/qps/`

### Install Steam
https://docs.fedoraproject.org/en-US/gaming/proton

Sometimes this command says  
"Failed to load RPM rpmfusion-free-release-44.noarch.rpm ... not a rpm"  
so do this first  
`sudo dnf clean all`

`sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y`

Fedora 41 or newer version pick this  
`sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1`

Fedora 40 or lower version pick this  
`sudo dnf config-manager --enable fedora-cisco-openh264 -y`

Finally  
`sudo dnf install steam -y`  
`steam`

Very important  
On first time start steam, use `steam` command instead of the graphical icon!  
This way you can know if you need a HTTP proxy  
in case steam client download is very slow  
That is, press Ctrl+C cancel download

You can just use a VPN as global proxy,  
or you have HTTP proxy server  
https://github.com/tazihad/ProxifierLinux  
Download as zip and unpack to somewhere  
in case you don't have git to download it  
cd into unpacked folder  
`sudo dnf install redsocks`

Clear default config file  
`sudo su`  
`> /etc/redsocks.conf`  
`exit`  
`sudo nano /etc/redsocks.conf`  
Paste content of `ProxifierLinux-main/redsocks.conf` and customize it  
`sudo ./start-proxifier.sh`  
Open a new terminal tab  
`steam`

Once steam install done, back to start-proxifier terminal tab,  
press Ctrl+Z then type command to stop it  
`sudo ./stop-proxifier.sh`

## Bypass virtual machine detect
Some game refuse to launch in a Linux virtual machine, whoa...  
https://forums.unraid.net/topic/127648-gaming-vm-cannot-run-under-virtual-machine-error-when-launching-game/  
under `<os>` put
```
    <smbios mode='host'/>
```

directly below that put this under `<features>`
```
    <kvm>
      <hidden state="on"/>
    </kvm>
```

under `<cpu mode ='host-passthrough'.......` put
```
    <feature policy="disable" name="hypervisor"/>
```
and also deleted any lines pertaining to hyper-v (hyperv)  
with a properly configured Linux virtual machine profile,  
hyperv related XML tags should not exist
