# Guest OS performance optimization
https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Performance_tuning

### Network
Change NIC "Device model" to virtio if possible  
On Windows, this require install driver in guest OS

### Windows

#### VirtIO
virtio-win driver is necessary for Windows guest OS to have good performance  
But a Windows virtual machine at the beginning can only boot with SATA controller  
instead of VirtIO SCSI controller

Boot under SATA by first, then download and install virtio drivers  
https://www.linux-kvm.org/page/WindowsGuestDrivers/Download_Drivers  
"Latest VirtIO drivers for Windows from Fedora"  
https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/index.html

Then use this tutorial to move system drive to VirtIO SCSI
https://www.reddit.com/r/Proxmox/comments/1d4jxc6/how_do_i_get_past_the_inaccessible_boot_device/

Change exist "Controller SCSI" Model to "VirtIO SCSI",  
or add one if there is no exist SCSI  
Shutdown, all disk **exclude** system drive,  
in XML change bus type from `sata` to `scsi`  
If you don't have second drive, create a new one and add to VirtIO SCSI  
Boot once to let Windows install VirtIO disk driver  
shutdown again and change system drive bus type  
from `sata` to `scsi` to see if it can boot

In simple, load other drive in VirtIO and boot once by first,  
then system drive

Assume Disk 1 is system drive, disk 2 to SCSI XML looks like:
```
<disk type="file" device="disk">
  <driver name="qemu" type="qcow2" cache="none" discard="unmap" detect_zeroes="unmap"/>
  ...
  <target dev="sdb" bus="scsi" rotation_rate="1"/>
  <address type="drive" controller="0" bus="0" target="0" unit="1"/>
</disk>
```

If that doesn't work, what original post says is...
1. Boot using SATA, SAS, IDE, Parallel SCSI, or VMware paravirtual SCSI and install VirtIO for Windows.
1. Tell Windows to boot into Safe Mode using "bcdedit /set "{current}" safeboot minimal" and shut down.
1. Change drive C: in Proxmox to use SATA.
1. Add a CD-ROM device in Proxmox to the VirtIO SCSI. You don't need any media.
1. Change boot order in Proxmox to boot from SATA
1. Start the machine. Since Windows notices the CD-ROM device in step (4) it will bake the VirtIO drivers into the system.
1. Disable Safe Mode using "bcdedit /deletevalue set "{current}" safeboot" and shut down.
1. Remove the CD-ROM device in Proxmox added in step (4).
1. Change drive C: in Proxmox to use VirtIO SCSI.
1. Change boot order in Proxmox to boot from VirtIO SCSI.
1. Start machine and you're done.

#### Red Hat Snake Oil for Windows guest OS
https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/configuring_and_managing_windows_virtual_machines/optimizing-windows-virtual-machines  
This is insane, replace exist settings with these improved performance a lot  
performance is back to Hyper-V Windows on Windows level

Replace exist "OS Information" XML with
```
    ...
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vendor_id state="on" value="KVM Hv"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <frequencies state="on"/>
      <reset state="on"/>
      <tlbflush state="on"/>
      <reenlightenment state="on"/>
      <stimer state="on">
        <direct state="on"/>
      </stimer>
      <ipi state="on"/>
    </hyperv>
    ...

  ...
  <clock offset="localtime">
    ...
    <timer name="hypervclock" present="yes"/>
  </clock>
  ...
```
After XML edit, boot and run this command inside Windows VM and reboot  
`bcdedit /set useplatformclock No`

Finally, shutdown and remove unused virtual hardware  
to save minor performance budget once everything tested fine

### CPU affinity / CPU Pinning
Let guest OS know Hyperthread, or avoid Hyperthread at all if you wish  
First in CPU settings and turn on "Manually set CPU topology"  
Most customer Hyperthread CPU have 2 thread per core  
Cores: 3, Threads: 2 will result in 6 vCPU allocation

Then go to "OS Information" XML  
This example prevent guest OS use Hyperthread by skip some thread number
```
  <vcpu placement="static">6</vcpu>
  <cputune>
    <vcpupin vcpu="0" cpuset="0"/>
    <vcpupin vcpu="1" cpuset="2"/>
    <vcpupin vcpu="2" cpuset="4"/>
    <vcpupin vcpu="3" cpuset="6"/>
    <vcpupin vcpu="4" cpuset="8"/>
    <vcpupin vcpu="5" cpuset="10"/>
  </cputune>
```

This example allow guest OS use Hyperthread and set affinity to last 3 core  
Separate KVM cores from VM cores,  
iothread equal to vcpu count and is start with 1 instead of 0  
If not boot, try avoid emulatorpin have same cpuset to vcpupin or remove it  
it work on some VM but doesn't on others for unknown reason
```
  <vcpu placement="static">6</vcpu>
  <iothreads>6</iothreads>
  <cputune>
    <vcpupin vcpu="0" cpuset="6"/>
    <vcpupin vcpu="1" cpuset="7"/>
    <vcpupin vcpu="2" cpuset="8"/>
    <vcpupin vcpu="3" cpuset="9"/>
    <vcpupin vcpu="4" cpuset="10"/>
    <vcpupin vcpu="5" cpuset="11"/>
    <emulatorpin cpuset="0-5"/>
    <iothreadpin iothread="1" cpuset="0-5"/>
    <iothreadpin iothread="2" cpuset="0-5"/>
    <iothreadpin iothread="3" cpuset="0-5"/>
    <iothreadpin iothread="4" cpuset="0-5"/>
    <iothreadpin iothread="5" cpuset="0-5"/>
    <iothreadpin iothread="6" cpuset="0-5"/>
  </cputune>
```

#### Remote performance
https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/frame-rate-limited-to-30-fps  
Guest OS registry editor  
`HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations`  
New, `DWORD (32-bit) Value`, `DWMFRAMEINTERVAL`, 15  
This allows 60 FPS RDP

### AMD Hyperthread
Set typology in Virtual Machine Manager CPU settings, then  
Inside XML CPU block, add feature tag below exist topology settings  
```
    <topology sockets="1" dies="1" clusters="1" cores="4" threads="2"/>
    <feature policy="require" name="topoext"/>
```

### Check host OS CPU power plan
https://wiki.debian.org/CpuFrequencyScaling  
https://wiki.cachyos.org/configuration/general_system_tweaks/  
Run these command on host OS instead of guest OS

`sudo apt install linux-cpupower`  
`cpupower frequency-info`  
Confirm is using driver `amd-pstate-epp` and "The governor" is "powersave"  
If governot is not powersave, set to powersave by  
`sudo cpupower frequency-set -g powersave`

Check current power plan  
`cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`

Say if I want something like Windows Balance power plan, and confirm applied  
`echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`  
`cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`

Note thant AMD suggest use balance instead of performance power plan  
energy_performance_preference has the following available options,  
order from power save to performance  
`power`, `balance_power`, `balance_performance`, `performance`

If you decide to change something instead of use default  
Set it to run on boot with this method  
https://gist.github.com/DavidAce/67bec5675b4a6cef72ed3391e025a8e5

`sudo nano /etc/systemd/system/cpu-tdp.service`
```
[Unit]
Description=Set CPU power

[Service]
Type=oneshot
ExecStartPre=cpupower frequency-set -g <what you want>
ExecStart=bash -c "echo <what you want> | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference;cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
```

`sudo nano /etc/systemd/system/cpu-tdp.timer`
```
[Unit]
Description=Set CPU power 5 seconds after boot

[Timer]
OnBootSec=5

[Install]
WantedBy=timers.target
```
`sudo systemctl enable --now cpu-tdp.timer`  
Verify value applied to CPU  
`cpupower frequency-info`  
`cat /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference`

## Pass USB controller as PCIe device
Audio device as "USB Host Device" doesn't work good  
on virtual machine is under heavy load  
Mouse with high polling rate also may cause performance problems  
People say compare to software redirection  
connect entire USB controller as PCIe device like graphics card removes overhead

USB Controller looks doesn't need special configuration,  
just add as PCI Host Device  
To confirm your USB device connected with which PCI, run  
`lsusb`
For example, a USB audio device named like "C-Media..."  
connected with Bus 003 Device 004, then looking for Bus 003 Device 001  
there should be "... root hub", once confirmed, run  
`lsusb -s <003>:<001> -v`  
Looking for "iSerial" in result  
remember it's value and add it to virual machine as PCI Host Device

## Low latency audio
When using Hyper-V GPU Partition,  
it often come with Sunshine and Steam Streaming Speaker  
If you run HeSuVi related stuff on Steam Streaming Speaker for 7.1 audio  
you may find after USB audio device pass to virtual machine directly  
the 7.1 output no longer available

To fix that install VB ASIO Bridge and ASIO4ALL  
https://vb-audio.com/Cable/#DownloadASIOBridge  
https://asio4all.org/about/download-asio4all/  
After install and reboot, set correct sample rate  
for both real audio interface and VB cable  
Open "ASIO Bridge" from start menu  
click on blue text in the middle "ASIO Device", choose ASIO4ALL  
Click on "ASIO OFF" to enable asio output  
Go to tray icon area find ASIO4ALL icon double click open settings  
Find your audio output device and click on power button to turn it on  
Drag ASIO buffer length as low as possible, higher if audio sounds not right  
close ASIO4ALL window, back to ASIO Bridge  
After test audio is fine, File, Check System Tray (Run at Startup)

Not all program support 64 buffer length  
if anything crashed adjust higher in ASIO4ALL settings

## If use shared memory
On my system ksm seems saves nothing and only waste 2~4% CPU  
(Saved 22 MB of total 64 GB)  
if not enable ksm, enable or not enable shared memory  
in virt-manager has no difference to performance  
I will turn off ksm, guide below are only for how to make ksm actually work

Most likely it's kernel same page merge  
https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/virtualization_tuning_and_optimization_guide/sect-ksm-the_ksm_tuning_service  
https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/virtualization_tuning_and_optimization_guide/chap-ksm  
https://gist.github.com/mapuo/17e3b253222172c1659782eb14150c3a  
The feature also require kernel same page merge on host system to be enabled for it to actually work

To check ksm status  
`watch -n 1 'grep -H . /sys/kernel/mm/ksm/pages_*'`  
`grep -r . /sys/kernel/mm/ksm/`

ksm/run: ksm is running or not  
ksm/pages_sharing: how many RAM saved by ksm

Commands to run as root example  
`taskset -cp 0-5 $(pgrep ksmd)`  
0-5 is CPU affinity, can also be `0,1` for first two core / thread

Advisor mode (cost more CPU to be faster)  
`echo <half of cpu cores 70*0.5=35 or default is 70> > /sys/kernel/mm/ksm/advisor_max_cpu`  
`echo scan-time > /sys/kernel/mm/ksm/advisor_mode`  
`echo 1 > /sys/kernel/mm/ksm/run`

Sleep mode (default)  
`echo 100 > /sys/kernel/mm/ksm/pages_to_scan`  
`echo 20 > /sys/kernel/mm/ksm/sleep_millisecs`  
`echo 1 > /sys/kernel/mm/ksm/run`  
https://www.kernel.org/doc/html/v6.6/admin-guide/mm/ksm.html  
Config and start ksm, check cpu usage of ksmd after start ksm  
if feels high adjust `pages_to_scan` and `sleep_millisecs` to lower  
Default is `100`, `20`

Create another pair of service and timer  
Pick advisor or sleep mode commands fill to `ExecStart=`  
`sudo nano /etc/systemd/system/cpu-ksm.service`
```
[Unit]
Description=Set kernel same page merge

[Service]
Type=oneshot
ExecStart=bash -c "taskset -cp 0-5 $(pgrep ksmd);echo 100 > /sys/kernel/mm/ksm/pages_to_scan;echo 20 > /sys/kernel/mm/ksm/sleep_millisecs;echo 1 > /sys/kernel/mm/ksm/run"
```

`sudo nano /etc/systemd/system/cpu-ksm.timer`
```
[Unit]
Description=Set kernel same page merge 5 seconds after boot

[Timer]
OnBootSec=5

[Install]
WantedBy=timers.target
```
`sudo systemctl enable --now cpu-ksm.timer`

