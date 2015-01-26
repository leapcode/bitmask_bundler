#!/bin/bash
######################################################################
# Copyright (C) 2013 LEAP
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
######################################################################

# This script is meant to be used as a bootstrapper for the environment to
# create a Bitmask bundle for Linux.

# This is tested to work on Debian 7.1 32 and 64 bits Virtual Machines

# This script uses `sudo` which is installed by default on debian, but you need
# to configure your non-root user to be able to use `sudo`.

# Edit the /etc/sudoers file and add this line at the bottom:
# leap ALL=NOPASSWD: ALL

# WARNING: That line allows the user 'leap' to use `sudo` without being asked
# for a password, that makes the script easier to use but it would be a
# security problem. If you use this script in a VM and only for bundling
# purposes then it shouldn't be a problem.

# You'll need an internet connection, approximately 1.3Gb of disk space and
# some patience.

################################################################################

set -e  # Exit immediately if a command exits with a non-zero status.

BASE='/home/leap/bitmask.bundle'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
VERSIONS_FILE="$SCRIPT_DIR/bitmask.json"
BINARY_COPIER="$SCRIPT_DIR/copy-binaries.sh"
ROOT_JSON="$SCRIPT_DIR/root.json"

# picked from https://github.com/OpenVPN/openvpn/releases
OPENVPN_VERSION="v2.3.6"

BOOST_MINOR="57"  # Minor version
BOOST_NAME="boost_1_${BOOST_MINOR}_0"

mkdir -p $BASE

# Note: we could use:
# ARCH=`uname -i`
# but it does not work on a VM (tested in i386 returns unknown)
if [[ `getconf LONG_BIT` == "64" ]]; then
    ARCH='x86_64-linux-gnu'
else
    ARCH='i386-linux-gnu'
fi

install_dependencies() {
    sudo apt-get update  # update apt, otherwise some packages may not be found
    sudo apt-get install -y build-essential python-dev cmake git autoconf \
        libtool liblzo2-dev libqt4-dev libxml2-dev libxslt1-dev qtmobility-dev \
        libsqlite3-dev libffi-dev python-virtualenv
}

build_boost() {
    cd $BASE

    wget -c http://ufpr.dl.sourceforge.net/project/boost/boost/1.${BOOST_MINOR}.0/${BOOST_NAME}.tar.bz2
    tar xjf ${BOOST_NAME}.tar.bz2

    # NOTE: this md5 is the only thing that they provide to verification.
    # for more information see: https://leap.se/code/issues/6296
    echo "1be49befbdd9a5ce9def2983ba3e7b76  boost_1_57_0.tar.bz2" | md5sum -c -

    cd $BOOST_NAME/tools/build/
    ./bootstrap.sh --with-toolset=gcc
    ./b2 install --prefix=$BASE/boost
    export PATH=$PATH:$BASE/boost/bin/

    cd $BASE/$BOOST_NAME # boost root
    b2 cxxflags=-std=c++0x --with-python --with-filesystem --with-system variant=release link=shared
}

build_launcher() {
    cd $BASE
    git clone -b develop https://leap.se/git/bitmask_launcher.git
    cd bitmask_launcher

    mkdir build
    cd build

    cmake -DBoost_INCLUDE_DIR=$BASE/$BOOST_NAME ..
    make
}

build_openvpn() {
    # Build openvpn to support RPATH
    cd $BASE
    git clone https://github.com/OpenVPN/openvpn.git --branch $OPENVPN_VERSION
    cd openvpn
    autoreconf -i
    LZO_LIBS="/usr/lib/$ARCH/liblzo2.a" ./configure LDFLAGS="-Wl,-rpath,lib/" --disable-snappy --disable-plugin-auth-pam
    make -j2
}

build_pyside() {
    # for more information look at:
    # https://github.com/PySide/pyside-setup/blob/master/docs/building/linux.rst
    cd $BASE
    sudo pip install wheel

    git clone https://github.com/PySide/pyside-setup.git pyside-setup.git
    cd pyside-setup.git
    python setup.py bdist_wheel --qmake=/usr/bin/qmake-qt4 --version=1.2.2
}

set_pyside_environment() {
    arch_bits=`getconf LONG_BIT`  # '32' or '64'
    # from https://github.com/PySide/BuildScripts/blob/master/environment.sh
    PYSIDE="$BASE/pyside-setup.git/pyside_install/py2.7-qt4.8.2-${arch_bits}bit-release/"
    PYTHONXY='python2.7'
    export PATH=$PYSIDE/bin:$PATH
    export PYTHONPATH=$PYSIDE/lib/$PYTHONXY/site-packages:$PYSIDE/lib64/$PYTHONXY/site-packages:$PYTHONPATH
    export LD_LIBRARY_PATH=$PYSIDE/lib:$LD_LIBRARY_PATH
    export PKG_CONFIG_PATH=$PYSIDE/lib/pkgconfig:$PKG_CONFIG_PATH
    export DYLD_LIBRARY_PATH=$PYSIDE/lib:$DYLD_LIBRARY_PATH
}

copy_binaries() {
    cp $ROOT_JSON $BASE
    cd $BASE
    $BINARY_COPIER
}

create_bundler_paths() {
    cd $BASE
    cat > bundler.paths << EOF
$BASE/bitmask_bundler.git/bundler
/usr/lib/python2.7
/usr/lib/python2.7/plat-linux2
/usr/lib/python2.7/lib-tk
/usr/lib/python2.7/lib-old
/usr/lib/python2.7/lib-dynload
/usr/local/lib/python2.7/dist-packages
/usr/lib/python2.7/dist-packages
/usr/lib/python2.7/dist-packages/gtk-2.0
/usr/lib/pymodules/python2.7
EOF
}

setup_bundler() {
    cd $BASE

    git clone https://github.com/leapcode/bitmask_bundler.git bitmask_bundler.git
    virtualenv bundler.venv && source bundler.venv/bin/activate

    # HACK: install these dependencies manually since they can't be installed normally due not passing some pip checks.
    pip install --upgrade pip
    pip install --allow-external u1db --allow-unverified u1db --allow-external dirspec --allow-unverified dirspec u1db dirspec

    # HACK: this is needed so tuf can verify the downloaded data, if we add
    # this to the requirements.pip pycrypto is installed as an egg and the
    # bundler can't copy its contents (not supported right now)
    pip install tuf[tools] pycrypto

    git clone https://github.com/chiiph/protobuf-socket-rpc protobuf-socket-rpc.git
    cd protobuf-socket-rpc.git
    python setup.py easy_install -Z .

    pip install -r $BASE/bitmask_bundler.git/pkg/requirements.pip
}

clean() {
    cd $BASE
    rm -fr bitmask_bundler.git bundler.venv protobuf-socket-rpc.git bundler.output
}

run_bundler() {
    cd $BASE

    # if the virtualenv is not sourced, then source it!
    # this is helpful if you want to run only this step
    [[ -z "$VIRTUAL_ENV"  ]] && source bundler.venv/bin/activate

    set_pyside_environment

    mkdir bundler.output

    # Use a shortcut for the bundler command
    bundler="python bitmask_bundler.git/bundler/main.py --workon bundler.output --binaries binaries/ --paths-file bundler.paths --versions-file $VERSIONS_FILE"

    $bundler --do gitclone
    $bundler --do gitcheckout
    copy_binaries

    $bundler --do pythonsetup

    # hack to solve gnupg version problem
    pip uninstall -y gnupg && pip install gnupg

    $bundler --skip gitclone gitcheckout pythonsetup
}

REUSE_BINARIES=$BASE/reuse-binaries.lock

if [[ ! -f $BINARY_COPIER ]]; then
    echo "ERROR: missing $BINARY_COPIER file."
    exit 1
fi

if [[ ! -f $VERSIONS_FILE ]]; then
    echo "ERROR: missing $VERSIONS_FILE file."
    exit 1
fi

if [[ ! -f $ROOT_JSON ]]; then
    echo "ERROR: missing $ROOT_JSON file."
    exit 1
fi

if [[ ! -f $REUSE_BINARIES ]]; then
    install_dependencies
    build_boost
    build_launcher
    build_openvpn
    build_pyside
    create_bundler_paths
else
    echo "Reusing existing binaries, cleaning up before creating a new bundle..."
    clean
fi

setup_bundler
run_bundler

echo 'If you remove this file the createbundle.sh script will rebuild all the binaries.' > $REUSE_BINARIES
