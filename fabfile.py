#!/usr/bin/env python
# encoding: utf-8
import json
import os

from fabric.api import task, cd, env, require, run, put


@task
def status():
    """
    Display some status of the server.
    """
    require('tuf_path', 'hosts', 'port', 'user')

    run('whoami')

    run('ls {0}/linux-i386 --color=auto'.format(env.tuf_path))
    run('ls {0}/linux-x86_64 --color=auto'.format(env.tuf_path))


@task
def update():
    """
    Update the TUF repo using the specified file name.
    """
    require('tuf_path', 'tuf_arch', 'hosts', 'port', 'user', 'repo_file')

    if env.tuf_arch not in ['32', '64']:
        print "Error: invalid parameter, use 32 or 64."
        return

    if not os.path.isfile(env.repo_file):
        print "Error: the file does not exist."
        return

    if env.tuf_arch == '32':
        arch = 'linux-i386'
    else:
        arch = 'linux-x86_64'

    path = os.path.join(env.tuf_path, arch)
    print arch, env.repo_file, path

    put(env.repo_file, path)

    with cd(path):
        # we keep the targets folder until we finish so we can recover it in
        # case of error
        run('mv targets targets.old')
        run('tar xjf {0} --strip-components=1'.format(env.repo_file))
        # NOTE: Don't copy the root.json file
        # run('cp -a metadata.staged/root.json metadata/')
        run('cp -a metadata.staged/targets.json* metadata/')
        run('cp -a metadata.staged/snapshot.json* metadata/')
        # '|| true' is a hack to avoid permissions problems
        run('chmod g+w -f -R metadata.staged/ metadata/timestamp.json || true')
        run('rm -fr targets.old')
        run('rm {0}'.format(env.repo_file))
        # Note: the timestamp is updated by cron


@task(default=True)
def help():
    print 'This script is meant to be used to update a TUF remote remository.'
    print 'You need to provide a fabfile.json containing server details and '
    print 'files to update. As an example see the fabfile.json.sample file.'
    print
    print 'Note: this assumes that you authenticate using the ssh-agent.'
    print
    print 'You should use this as follows:'
    print '  fab update'


def load_json():
    """
    Load a fabfile.json file and add its data to the 'env' dict.
    """
    # NOTE hopefully this will be available soon on fabric,
    # see https://github.com/fabric/fabric/pull/1092
    try:
        jdata = None
        with open('fabfile.json', 'r') as f:
            jdata = json.load(f)

        env.update(jdata)
        print "ENV updated"
    except:
        print "ENV not updated"
        pass


# Do this always and as a first task
load_json()
