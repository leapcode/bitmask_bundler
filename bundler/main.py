# TODO:
#  - Check if inside a virtualenv, and warn before doing anything
#  - Build everything that we are currently expecting as a binary
#  - Create complete bundle changelog

import argparse
import json
import os
import tempfile

from contextlib import contextmanager
from distutils import dir_util

from actions import GitCloneAll, GitCheckout, PythonSetupAll
from actions import CollectAllDeps, CopyBinaries, PLister, SeededConfig
from actions import DarwinLauncher, CopyAssets, CopyMisc, FixDylibs
from actions import DmgIt, PycRemover, TarballIt, MtEmAll, ZipIt, SignIt
from actions import RemoveUnused, CreateDirStructure

from utils import IS_MAC, IS_WIN

sorted_repos = [
    "leap_assets",
    "leap_pycommon",
    "keymanager",
    "soledad",
    "leap_mail",
    "bitmask_client",
    "bitmask_launcher",
]


@contextmanager
def new_build_dir(default=None):
    bd = default
    if bd is None:
        bd = tempfile.mkdtemp(prefix="bundler-")
    yield bd
    # Only remove if created a temp dir
    if default is None:
        dir_util.remove_tree(bd)


def get_version(versions_file):
    """
    Return the "version" data on the json file given as parameter.

    :param versions_file: the file name of the json to parse.
    :type versions_file: str

    :rtype: str or None
    """
    version = None
    try:
        versions = None
        with open(versions_file, 'r') as f:
            versions = json.load(f)

        version = versions.get("version")
    except Exception as e:
        print "Problem getting version: {0!r}".format(e)

    return version


def main():
    parser = argparse.ArgumentParser(description='Bundle creation tool.')
    parser.add_argument('--workon', help="")
    parser.add_argument('--skip', nargs="*", default=[], help="")
    parser.add_argument('--do', nargs="*", default=[], help="")
    parser.add_argument('--paths-file', help="")
    parser.add_argument('--versions-file', help="")
    parser.add_argument('--binaries', help="")
    parser.add_argument('--seeded-config', help="")
    parser.add_argument('--codesign', default="", help="")

    args = parser.parse_args()

    assert args.paths_file is not None, \
        "We need a paths file, otherwise you'll get " \
        "problems with distutils and site"
    paths_file = os.path.realpath(args.paths_file)

    assert args.binaries is not None, \
        "We don't support building from source, so you'll need to " \
        "specify a binaries path"
    binaries_path = os.path.realpath(args.binaries)

    assert args.versions_file is not None, \
        "You need to specify a versions file with the versions to use " \
        "for each package."
    versions_path = os.path.realpath(args.versions_file)

    seeded_config = None
    if args.seeded_config is not None:
        seeded_config = os.path.realpath(args.seeded_config)

    with new_build_dir(os.path.realpath(args.workon)) as bd:
        print "Doing it all in", bd

        def init(t, bd=bd):
            return t(bd, args.skip, args.do)

        gc = init(GitCloneAll)
        gc.run(sorted_repos)

        # NOTE: NEW...
        gco = init(GitCheckout)
        gco.run(sorted_repos, versions_path)

        ps = init(PythonSetupAll)
        ps.run(sorted_repos, binaries_path)

        cd = init(CreateDirStructure, os.path.join(bd, "Bitmask"))
        cd.run()

        dp = init(CollectAllDeps)
        dp.run(paths_file)

        if binaries_path is not None:
            cb = init(CopyBinaries)
            cb.run(binaries_path)

        if IS_MAC:
            pl = init(PLister)
            pl.run()
            dl = init(DarwinLauncher)
            dl.run()
            ca = init(CopyAssets)
            ca.run()
            fd = init(FixDylibs)
            fd.run()

        cm = init(CopyMisc)
        cm.run(binaries_path)

        pyc = init(PycRemover)
        pyc.run()

        if IS_WIN:
            mt = init(MtEmAll)
            mt.run()

        if IS_MAC:
            si = init(SignIt)
            si.run(args.codesign)

        if seeded_config is not None:
            sc = init(SeededConfig)
            sc.run(seeded_config)

        version = get_version(versions_path)

        if IS_MAC:
            dm = init(DmgIt)
            dm.run(sorted_repos, version)
        elif IS_WIN:
            zi = init(ZipIt)
            zi.run(sorted_repos, version)
        else:
            ru = init(RemoveUnused)
            ru.run()
            ti = init(TarballIt)
            ti.run(sorted_repos, version)

        # do manifest on windows

if __name__ == "__main__":
    main()
