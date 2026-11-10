# `toggle.sh`
This script has purpose
- Toggle which virtual machine run and control graphics card
- Send ACPI shutdown signal to specified virtual machine  
  what not getting shutdown is to be hibernated

## Usage
Download to a new blank folder, only for this script  
to store Tab autocomplete files

Script use systemd environment.d to transfer environment variables

Environment variable `VM_WITH_GPU_PASSTHROUGH` is tell script  
which vm has GPU passthrough  
Script will shutdown all vm name in this variable  
and boot the one you want toggle to  
`nano ~/.config/environment.d/vm.conf`
```
VM_WITH_GPU_PASSTHROUGH="<vm name 1>,<vm name 2>,<vm name 3>..."
```
Logout and login or reboot to apply

Environment variable `VM_ADDITIONAL_SHUTDOWN`  
is for tell script which vm to shutdown on `-s` argument is specified  
This variable change more frequently,  
reload systemd unit file is easier than reload environment.d  
so it usually define in systemd unit file as `Environment=`

Add execute premission after download  
`chmod +x ./toggle.sh`

Show help text and **read it**, press Ctrl+C to do nothing  
`./toggle.sh -h`

After all done, install script in the following steps

## Run script to toggle
Go to end of `.bashrc` file and append  
`nano ~/.bashrc`
```
...
alias toggle="(cd $HOME/<toggle.sh folder> && VM_WITH_GPU_PASSTHROUGH=$VM_WITH_GPU_PASSTHROUGH sudo -E ./toggle.sh)"
```
`source ~/.bashrc`  
`tog<Press Tab and hit Enter to run it>`

Script will ask which virtual machine toggle to  
make sure every virtual machine will response to ACPI shutdown signal  
instead of blocking it

## Run script on shutdown
`sudo nano /etc/systemd/system/kvm-shutdown-action.service`
```
[Unit]
Description=Run on shutdown
Requires=network-online.target
After=libvirt-guests.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=/path/to/your/shutdown/script/toggle.sh -s
User=root
EnvironmentFile=/home/<username>/.config/environment.d/vm.conf
Environment="VM_ADDITIONAL_SHUTDOWN=<vm name 4>,<vm name 5>,<vm name 6>..."

[Install]
WantedBy=multi-user.target
```
