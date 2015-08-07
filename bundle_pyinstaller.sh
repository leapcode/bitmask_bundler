#!/bin/bash
######################################################################
# bundle_pyinstaller.sh
# Copyright (C) 2015 LEAP
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
set -e  # Exit immediately if a command exits with a non-zero status.

REPOSITORIES="bitmask_client leap_pycommon soledad keymanager leap_mail"
PACKAGES="leap_pycommon keymanager soledad/common soledad/client leap_mail bitmask_client"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
REPOS_ROOT="$SCRIPT_DIR/repositories"  # Root path for all the needed repositories
VENV_DIR="$SCRIPT_DIR/bitmask.venv"  # Root path for all the needed repositories


# To get colored output you should run this script like this:
# ENABLE_COLORS=1 ./this_script.sh
if [[ -z $ENABLE_COLORS ]]; then
    cc_green=""
    cc_yellow=""
    cc_red=""
    cc_normal=""
else
    # Escape codes - set colors
    esc=`echo -en "\033"`
    cc_green="${esc}[0;32m"
    cc_yellow="${esc}[0;33m"
    cc_red="${esc}[0;31m"
    cc_normal=`echo -en "${esc}[m\017"`
fi

mkdir -p $REPOS_ROOT

_cdsitepackages(){
    # from http://stackoverflow.com/a/122340/687989
    site_packages=`python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())"`
    cd $site_packages
}

create_venv() {
    status="creating virtualenv"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    virtualenv $VENV_DIR && source $VENV_DIR/bin/activate
    pip install --upgrade pip  # get the latest pip

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

install_pyinstaller(){
    status="installing pyinstaller from repo"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands
    source $VENV_DIR/bin/activate
    cd $REPOS_ROOT

    if [ ! -d pyinstaller ]; then
        git clone https://github.com/kalikaneko/pyinstaller.git --branch feature/pyside-hooks --depth 1
        cd pyinstaller
    else
        cd pyinstaller
        git fetch origin
        git reset --hard origin/develop
    fi

    python setup.py develop

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

clone_repos() {
    status="clone repositories"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    src="https://leap.se/git"
    cd $REPOS_ROOT

    for repo in $REPOSITORIES; do
        echo "${cc_yellow}Status: cloning: $repo...${cc_normal}"
        if [ ! -d $repo ]; then
           git clone -b develop $src/$repo --depth 1
       else
           cd $repo
           git fetch
           git reset --hard origin/develop
           cd ..
       fi
    done

    set +x
    echo "${cc_green}Status: $status done!${cc_normal}"
}

install_requirements() {
    status="installing non-leap requirements"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands
    cd $REPOS_ROOT
    source $VENV_DIR/bin/activate

    cd $REPOS_ROOT/bitmask_client/
    make install_base_deps
    pip install -U --no-index --trusted-host lizard.leap.se --find-links=https://lizard.leap.se/wheels pyside
    # ./pkg/postmkvenv.sh

    # hack to solve gnupg version problem
    pip uninstall -y gnupg && pip install gnupg

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

create_sumo(){
    echo "${cc_red}No sumo creation available in here.${cc_normal}"
    exit  # no creation, get sumo from path
    status="creating sumo tarball"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands


    # source $VENV_DIR/bin/activate
    # cd $REPOS_ROOT/bitmask_client/
    # python setup.py sdist --sumo
}

install_sumo(){
    if [[ -z $1 ]]; then
        echo "You need to specify a sumo tarball path parameter."
        exit 1
    fi

    status="'installing' sumo tarball"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    source $VENV_DIR/bin/activate
    SUMO_PATH=$1

    _cdsitepackages

    # the file name may be like 'leap.bitmask-0.9.0rc1-12-g59bc704-SUMO.tar.gz',
    # but it also can be 'leap.bitmask-latest-SUMO.tar.gz'
    # and the root path inside the archive for that file would be
    # 'leap.bitmask-0.9.0rc1-12-g59bc704-SUMO' in both cases.
    base_path=`tar tzf $SUMO_PATH | head -n 1`
    target_subpath=src/leap
    tar xzf $SUMO_PATH $base_path$target_subpath --strip-components=2
}

add_files(){
    # HACK: this is only a hack around a missing pyinstaller hook
    status="hack: add files"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    _cdsitepackages

    dest="$REPOS_ROOT/bitmask_client/pkg/pyinst/cryptography/"
    mkdir -p $dest
    cp cryptography/hazmat/bindings/openssl/src/osrandom_engine.{c,h} $dest

    dest="$REPOS_ROOT/bitmask_client/dist/bitmask/u1db/backends/"
    mkdir -p $dest
    cp u1db/backends/dbschema.sql $dest

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

tweak_linux(){
    status="tweaking linux specific stuff"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    cd $REPOS_ROOT/bitmask_client/dist/bitmask
    mv bitmask bitmask-app

    cd $REPOS_ROOT/bitmask_client
    cp pkg/linux/bitmask-launcher dist/bitmask/bitmask

    cd $REPOS_ROOT/bitmask_client
    mkdir -p dist/bitmask/helpers
    cp pkg/linux/bitmask-root dist/bitmask/helpers/

    # NOTE: TUF stuff is needed for all OSs, not just linux
    # TODO: copy launcher.conf for TUF updates
    # cp pkg/tuf/launcher.conf dist/bitmask/helpers/

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

tweak_zope(){
    # - create bare zope dir in site-packages
    # - touch zope/__init__.py
    # - move the zope.interface folder to zope/
    # - move the zope.proxy folder to zope/
    # - remove the zope* eggs in site-packages
    # - remove any refs to these eggs in easy-install.pth ?? (unsure about this, talking from the top of my head) 
    status="tweaking zope packages"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    _cdsitepackages
    mkdir -p zope
    touch zope/__init__.py
    # zope/interface and zope/proxy already in place
    rm -fr zope.{interface,proxy}*.egg-info
    rm -f zope.{interface,proxy}*-nspkg.pth
    cd -

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

run_pyinstaller(){
    status="running pyinstaller"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    spec_file=$1
    cd $REPOS_ROOT/bitmask_client
    make clean_pkg

    # HACK: path needed by bitmask_client makefile
    mkdir -p $REPOS_ROOT/bitmask_client/dist/Bitmask.app/Contents/Resources/

    make pyinst

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

archive_bundle(){
    # - rename dist/bitmask distribution folder to bitmask-<release>-<date?>
    status="creating bundle archive"
    echo "${cc_green}Status: $status...${cc_normal}"
    set -x  # show commands

    source $VENV_DIR/bin/activate
    version=`python -c "import leap.bitmask; print leap.bitmask.__version__"`

    cd $REPOS_ROOT/bitmask_client/dist/
    # TODO: add version to bundle name
    # `git describe` won't work if shallow clone (--depth 1)
    BUNDLE_NAME="bitmask-$version"
    mv bitmask $BUNDLE_NAME
    tar czf $SCRIPT_DIR/$BUNDLE_NAME.tar.gz $BUNDLE_NAME

    set +x
    echo "${cc_green}Status: $status done.${cc_normal}"
}

if [[ -z $1 ]]; then
    echo "Bitmask pyinstaller creator."
    echo "You need to specify the sumo tarball path as a parameter."
    echo "Usage:"
    echo "  $0 path/to/sumo.tar.gz"
    exit 1
fi

sumo_path=`realpath $1`

create_venv
install_pyinstaller
clone_repos
install_requirements
install_sumo $sumo_path
tweak_zope
add_files
run_pyinstaller
tweak_linux
archive_bundle
