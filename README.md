# Bundler

This application is intended to create [Bitmask](https://bitmask.net)
[standalone bundles](https://bitmask.net/en/install/linux#install-stand-alone-bundle).
This should eventually become the main tool in order to create reproducible
builds.

## What do you need

* Two virtual machines:
  * Debian 7.1 32bits - for the 32bits bundle
  * Debian 7.1 64bits - for the 64bits bundle
* two scripts in this repository,
* an internet connection,
* approximately 1.3Gb of disk space,
* (optional) configure `sudo` for your non-root user,
* patience.

The script uses `sudo` which is installed on most Debian systems, but you need
to configure your non-root user to be able to use `sudo`.

Edit the `/etc/sudoers` file and add this line at the bottom:
`leap ALL=NOPASSWD: ALL`

*HEADS UP*: That line allows the user 'leap' to use `sudo` without being asked
for a password, that makes the script easier to use but it would be a security
problem. If you use this script in a VM and only for bundling purposes then it
shouldn't be a problem.




## How to use

You need to copy the scripts `createbundle.sh` and `copy-binaries.sh` to a VM
and run `./createbundle.sh`, after that it should be all automagically
processed.
As an input for the `createbundle.sh` script you need to have a `bitmask.json`
file in the same folder, there is an example file on this repo, you can use it
as a template. There is a json file named `bitmask-nightly.json` that is meant
to be used to create a bundle combining all the `develop` branches.

The resulting bundle will be saved in:
`/home/leap/bitmask.bundle/bundle.output/` under some name like
`Bitmask-linux64-2014-09-24-9b3b7f6f.tar.bz2` in case of bundling a *nightly*
release, or `Bitmask-linux64-0.7.0.tar.bz2` in case of a *normal* release.

After the bundling process finishes it creates a file named
`reuse-binaries.lock` that if you don't delete it, the bundler will reuse the
compiled libraries and binaries (like `openvpn` and `PySide`) saving a lot of
time the next time that a bundler is executed.
