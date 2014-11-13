#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

BASE='/home/leap/bitmask.bundle'
BOOST_MINOR="57"
BOOST="$BASE/boost_1_${BOOST_MINOR}_0"

# Note: we could use:
# ARCH=`uname -i`
# but it does not work on a VM (tested in i386 returns unknown)
if [[ `getconf LONG_BIT` == "64" ]]; then
    ARCH='x86_64-linux-gnu'
else
    ARCH='i386-linux-gnu'
fi

cd $BASE
rm -fr binaries
mkdir binaries && cd binaries

cp /usr/bin/gpg .
cp $BASE/bitmask_launcher/build/src/launcher bitmask
cp $BOOST/stage/lib/libboost_filesystem.so.1.${BOOST_MINOR}.0 .
cp $BOOST/stage/lib/libboost_python.so.1.${BOOST_MINOR}.0 .
cp $BOOST/stage/lib/libboost_system.so.1.${BOOST_MINOR}.0 .

cp $BASE/pyside-setup.git/pyside_package/PySide/libpyside-python2.7.so.1.2 .
cp $BASE/pyside-setup.git/pyside_package/PySide/libshiboken-python2.7.so.1.2 .

cp /usr/lib/$ARCH/libQtGui.so libQtGui.non-ubuntu
cp /usr/lib/$ARCH/libQtCore.so libQtCore.non-ubuntu

cp /usr/lib/$ARCH/libaudio.so.2 .
cp /usr/lib/$ARCH/libffi.so.5 .
cp /usr/lib/$ARCH/libfontconfig.so.1 .
cp /lib/$ARCH/libpng12.so.0 .  # NOTE: it should be libpng15.so.15
cp /usr/lib/libpython2.7.so.1.0 .
cp /usr/lib/$ARCH/libssl.so.1.0.0 .
cp /usr/lib/$ARCH/libstdc++.so.6 .

# NOTE: this needs to be always the same root.json file
cp $BASE/root.json .

mkdir openvpn.files && cd openvpn.files
cp $BASE/openvpn/src/openvpn/openvpn leap-openvpn

cp $BASE/bundler.output/bitmask_client/pkg/linux/bitmask-root .
cp $BASE/bundler.output/bitmask_client/pkg/linux/leap-install-helper.sh .
cp $BASE/bundler.output/bitmask_client/pkg/linux/polkit/se.leap.bitmask.bundle.policy .
chmod +x bitmask-root
chmod +x leap-install-helper.sh
