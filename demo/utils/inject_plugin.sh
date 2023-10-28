#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <target.so> <destination>"
    exit 1
fi

lib="$1"
destination="$2"

sudo mkdir -p "$destination"
sudo cp -f "$1" "$destination"
dependencies=$(ldd "$lib" | awk '{print $3}' | grep -v 'not found')
not_found=$(ldd "$lib" | awk '/not found/{print $1}')
if [ -n "$not_found" ]; then
    echo "Inject plugin failed. Because the below dependencies are not found:"
    echo "$not_found"
fi

for dep in $dependencies; do
    if [ -f "$dep" ]; then
        sudo cp -f "$dep" "$destination"
    fi
done