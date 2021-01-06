#!/bin/bash

set -ex

grep 'centos:7' /etc/os-release && centOS7=true || centOS7=false

if $centOS7; then
    yum -y install libXi
    yum -y install libXxf86vm
    yum -y install libXfixes
    yum -y install libXrender
    yum -y install libGL
else # CentOS8
    dnf -y install libXi
    dnf -y install libXxf86vm
    dnf -y install libXfixes
    dnf -y install libXrender
    dnf -y install libGL
fi

cd /usr/local/bin

downloadUrl='https://mediasolutions.blob.core.windows.net/bin/Blender'

fileName='blender2910.tar.xz'
curl -L -o $fileName $downloadUrl/blender-2.91.0-linux64.tar.xz
tar -xJf $fileName
mv blender-*/* .
