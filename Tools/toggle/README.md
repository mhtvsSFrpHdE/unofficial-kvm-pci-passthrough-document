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
EnvironmentFile=/home/<username>/.config/environment.d/vm.conf
Environment="VM_ADDITIONAL_SHUTDOWN=<vm name 3>,<vm name 4>,<vm name 5>..."

[Install]
WantedBy=multi-user.target
```