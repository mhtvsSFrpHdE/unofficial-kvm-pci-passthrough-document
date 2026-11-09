#!/bin/bash

# `cd` into a large working directory as temp storage
# Argument 1: input disk file
# Argument 2: output disk file

mkdir Temp

qemu-img convert -p -f vhdx -O qcow2 $1 $2
sudo TMPDIR="$(pwd)/Temp" virt-sparsify $1 $2
sudo chown root:root $2
sudo chmod 600 $2
