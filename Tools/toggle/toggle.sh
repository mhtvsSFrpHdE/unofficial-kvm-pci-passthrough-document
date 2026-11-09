#!/bin/bash

argHelp=false
argNewAutoCompleteFile=false
argShutdown=false
for arg in "$@"; do
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    argHelp=true
  fi
  if [[ "$arg" == "-n" ]]; then
    argNewAutoCompleteFile=true
  fi
  if [[ "$arg" == "-s" ]]; then
    argShutdown=true
  fi
done

# Help
if $argHelp; then
    echo Environment variables
    echo "VM_WITH_GPU_PASSTHROUGH=\"vm1,vm2,vm3\""
    echo "    Define vm name in environment variable like this"
    echo "    To ensure you type right vm name later"
    echo "VM_ADDITIONAL_SHUTDOWN=\"vm4,vm5,vm6\""
    echo "    If defined, vm name will shutdown together when -s is specified"
    echo
    echo Options
    echo "-n    Run script with -n argument once"
    echo "    To generate virtual machine name autocomplete file"
    echo "    Then during type vm name you can autocomplete with Tab"
    echo "-s    Shutdown only, skip start virtual machine after shutdown"
    echo
    echo Usage
    echo "    Make sure your virtual machine doesn't block ACPI shutdown signal"
    echo "    The \"Power\" button on PC"
    echo "    For example, on KDE, settings required"
    echo "    System Settings, System, Power Managerment, Suspend Session"
    echo "    When power button pressed: Change to \"Shutdown\""
    echo "    On Windows, Settings, Accounts, Sign-in options"
    echo "    Set to off: Use my sign-in info to automatically finish setting up after an update"
    echo
    echo "    Run script with root to prevent wait too long cause sudo timeout"
    echo "    and stuck in password prompt"
    echo
fi

# Import environment variable from systemd environment.d
eval $(/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator)

# Parse environment variable to array, delimiter by ","
IFS=',' read -ra vmWithGpuPassthrough <<< "$VM_WITH_GPU_PASSTHROUGH"

# Create empty file with VM name
# so you can press Tab for autocomplete later
# (read -e autocomplete by files in current directory)
if $argNewAutoCompleteFile; then
    echo "I'll create some files in current working directory"
    echo "Please run -n in dedicated folder"
    echo "Press Ctrl+C to cancel"
    read -p "Press Enter to continue..."
    echo
    for vmName in "${vmWithGpuPassthrough[@]}"; do
      touch $vmName
    done
    echo "Autocomplete file in working directory:"
    # Print working directory content but hide script file itself from result
    scriptFileName=$(basename -- "${BASH_SOURCE[0]}")
    ls -1 -I $scriptFileName
    exit
fi

if [ -z "${VM_WITH_GPU_PASSTHROUGH}" ]; then
  echo "Not detected environment variable VM_WITH_GPU_PASSTHROUGH"
  echo "Try \"sudo -E ./toggle.sh\"?"
  exit
fi

if ! $argShutdown; then
  # https://github.com/crc-org/snc/pull/42
  echo "VM_WITH_GPU_PASSTHROUGH:"
  printf '%s\n' "${vmWithGpuPassthrough[@]}"
  # Loop until user type right vm name defined in VM_WITH_GPU_PASSTHROUGH
  while true; do
    read -e -p "Swap graphics card to vm name: " vmNameToStart

    found=0
    for vmName in "${vmWithGpuPassthrough[@]}"; do
      if [[ "$vmName" == "$vmNameToStart" ]]; then
        found=1
        break
      fi
    done

    if [[ $found -eq 1 ]]; then
      break
    else
      echo "Not a GPU virtual machine defined in environment variable VM_WITH_GPU_PASSTHROUGH"
    fi
  done
fi

# Request shutdown to each vm inside VM_WITH_GPU_PASSTHROUGH
for vmName in "${vmWithGpuPassthrough[@]}"; do
  virsh shutdown "$vmName"
  until virsh domstate $vmName | grep shut; do
    echo "Waiting for shutdown: $vmName"
    sleep 1
  done
done

# Request shutdown to each vm inside VM_ADDITIONAL_SHUTDOWN
if $argShutdown; then
  IFS=',' read -ra vmAdditionalShutdown <<< "$VM_ADDITIONAL_SHUTDOWN"
  for vmName in "${vmAdditionalShutdown[@]}"; do
    virsh shutdown "$vmName"
    until virsh domstate $vmName | grep shut; do
      echo "Waiting for shutdown: $vmName"
      sleep 1
    done
  done
fi

# After all shutdown
if ! $argShutdown; then
  sleep 5
  virsh start "$vmNameToStart"
fi

echo Script finished
