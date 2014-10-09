#!/bin/bash

# Needed files:
#   Bitmask-linux32-0.7.0.tar.bz2  # fresh bundled bundle
#   Bitmask-linux64-0.7.0.tar.bz2  # fresh bundled bundle
#   tuf_private_key.pem            # private key
#   tuf-stuff.sh                   # this script

# Output:
#   workdir/ <-- temporary folder: virtualenv, bundle, repo.tar.gz, key
#   output/  <-- here you'll find the resulting compressed repo/bundle


# Expected directory structure for the repo after the script finishes:
# $ tree workdir/repo/
# repo
# ├── metadata.staged
# │   ├── root.json
# │   ├── snapshot.json
# │   ├── snapshot.json.gz
# │   ├── targets.json
# │   ├── targets.json.gz
# │   └── timestamp.json
# └── targets
#     ... Bitmask bundle files ...

set -e  # Exit immediately if a command exits with a non-zero status.

# Set some colors variables
esc=`echo -en "\033"`
cc_red="${esc}[31m"
cc_green="${esc}[32m"
cc_yellow="${esc}[33m"
cc_normal="${esc}[39m"

show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-r FILE] [-s] [-a (32|64)] -v VERSION -k KEY_FILE
Do stuff for version VERSION and arch ARCH.

    -h           display this help and exit.
    -a ARCH      do the tuf stuff for that ARCH, 32 or 64 bits. The default is '64'.
    -k KEY_FILE  use this key file to sign the release
    -r FILE      use particular repo/ file to do the tuf stuff. FILE must be a .tar.gz file.
    -s           run the setup process, create virtualenv and install dependencies.
    -v VERSION   version to work with. This is a mandatory argument.
EOF
}

get_args() {
    # from: http://mywiki.wooledge.org/BashFAQ/035#getopts
    local OPTIND

    ARCH="64"
    SETUP="NO"

    while getopts "hr:sv:a:k:" opt; do
        case "$opt" in
            h)
                show_help
                exit 0
                ;;
            v)  VERSION=$OPTARG
                ;;
            r)  REPO=`realpath $OPTARG`
                ;;
            s)  SETUP='YES'
                ;;
            k)  KEY_FILE=`realpath $OPTARG`
                ;;
            a)  ARCH=$OPTARG
                ;;
            '?')
                show_help >&2
                exit 1
                ;;
        esac
    done
    shift "$((OPTIND-1))" # Shift off the options and optional --.

    if [[ -z $VERSION ]]; then
        echo 'Error: missing -v flag'
        show_help
        exit 1
    fi
    if [[ -z $KEY_FILE ]]; then
        echo 'Error: missing -k flag'
        show_help
        exit 1
    fi

    echo "---------- settings ----------"
    echo "Arch: $ARCH"
    echo "Key: $KEY_FILE"
    echo "Repo: $REPO"
    echo "Setup: $SETUP"
    echo "Version: $VERSION"
    echo "--------------------"
    read -p "Press <Enter> to continue, <Ctrl>+C to exit. "
}

# ----------------------------------------

do_init(){
    # Initialize the needed variables and create the work directory.

    BASE=`pwd`
    WORKDIR=$BASE/workdir
    VENVDIR=$WORKDIR/tuf.venv

    BITMASK="Bitmask-linux$ARCH-$VERSION"
    RELEASE=$BASE/../bitmask_client/pkg/tuf/release.py

    # Initialize path
    mkdir -p $WORKDIR
}

do_setup() {
    # Create a clean virtualenv and install the needed dependencies.
    echo "${cc_yellow}-> Setting up virtualenv and installing dependencies...${cc_normal}"
    cd $WORKDIR

    # remove existing virtualenv
    [[ -d $VENVDIR ]] && rm -fr $VENVDIR

    virtualenv $VENVDIR
    source $VENVDIR/bin/activate
    pip install tuf[tools] pycrypto
}

do_tuf_stuff() {
    cd $WORKDIR
    cp $BASE/$BITMASK.tar.bz2 .

    rm -fr repo/
    mkdir repo && cd repo/

    if [[ $ARCH == "64" ]]; then
        TUF_ARCH='linux-x86_64'
    else
        TUF_ARCH='linux-i386'
    fi

    if [[ -z $REPO ]]; then
        # Download old repo metadata
        echo "${cc_yellow}-> Downloading metadata files from the old bundle...${cc_normal}"
        wget --quiet --recursive --no-host-directories --cut-dirs=2 --no-parent --reject "index.html*" https://dl.bitmask.net/tuf/$TUF_ARCH/metadata/
        mv metadata metadata.staged
    else
        echo "${cc_yellow}-> Extracting metadata files from the repo file...${cc_normal}"
        # we need that specific folder without the repo/ parent path
        tar xzf $REPO repo/metadata.staged/ --strip-components=1
    fi

    echo "${cc_yellow}-> Uncompressing bundle and moving to its place...${cc_normal}"
    tar xjf $BASE/$BITMASK.tar.bz2  # fresh bundled bundle
    rm -fr $BITMASK/repo/  # We must not add that folder to the tuf repo.
    rm -fr targets
    mv $BITMASK targets

    echo "${cc_yellow}-> Doing release magic...${cc_normal}"
    $RELEASE $WORKDIR/repo $KEY_FILE

    echo "${cc_yellow}-> Creating output file...${cc_normal}"
    cd $WORKDIR
    mkdir -p output
    rm -f output/$BITMASK-tuf.tar.bz2
    tar cjf output/$BITMASK-tuf.tar.bz2 repo/
}


get_args $@

do_init

if [[ $SETUP == 'YES' ]]; then
    do_setup
else
    if [[ ! -f $VENVDIR/bin/activate ]]; then
        echo "${cc_red}Error:${cc_normal} missing virtualenv, you need to use the -s switch."
        exit 1
    fi
    source $VENVDIR/bin/activate
fi

do_tuf_stuff

echo "${cc_green}TUF release complete.${cc_normal}"
echo "You can find the resulting file in:"
echo "$WORKDIR/output/$BITMASK-tuf.tar.bz2"
