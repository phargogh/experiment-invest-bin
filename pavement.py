import os
import logging
import sys
import json
import subprocess
import platform
import collections
import getpass
import shutil

import hglib
import paver.virtual
import paver.svn
from paver.easy import *

LOGGER = logging.getLogger('invest-bin')
_SDTOUT_HANDLER = logging.StreamHandler(sys.stdout)
_SDTOUT_HANDLER.setLevel(logging.INFO)
LOGGER.addHandler(_SDTOUT_HANDLER)


class Repository(object):
    tip = ''
    statedir = ''

    def __init__(self, local_path, remote_url):
        self.local_path = local_path
        self.remote_url = remote_url

    def ischeckedout(self):
        return os.path.exists(os.path.join(self.local_path, self.statedir))

    def clone(self):
        raise Exception

    def pull(self):
        raise Exception

    def update(self):
        raise Exception

    def tracked_version(self):
        return json.load(open('versions.json'))[self.local_path]

    def current_rev(self):
        raise Exception

class HgRepository(Repository):
    tip = 'tip'
    statedir = '.hg'

    def clone(self):
        sh('hg clone %(url)s %(dest)s' % {'url': self.remote_url,
                                          'dest': self.local_path})

    def pull(self):
        sh('hg pull -R %(dest)s' % {'dest': self.local_path})

    def update(self, rev):
        sh('hg update -R %(dest)s -r %(rev)s' % {'dest': self.local_path,
                                               'rev': rev})

    def current_rev(self):
        return sh('hg log -r . --template={node}', capture=True)

class SVNRepository(Repository):
    tip = 'HEAD'
    statedir = '.svn'

    def clone(self):
        paver.svn.checkout(self.remote_url, self.local_path)

    def pull(self):
        # svn is centralized, so there's no concept of pull without a checkout.
        return

    def update(self, rev):
        paver.svn.update(self.local_path, rev)

    def current_rev(self):
        return paver.svn.info(self.local_path).revision

SCMS = {
    'hg': HgRepository,
    'svn': SVNRepository,
}

REPOS = [
    {
        'path': 'src/pygeoprocessing',
        'scm': 'hg',
        'url': 'https://bitbucket.org/richpsharp/pygeoprocessing',
    },
    {
        'path': 'doc/users-guide',
        'scm': 'hg',
        'url': 'http://code.google.com/p/invest-natcap.users-guide',
    },
    {
        'path': 'data/invest-data',
        'scm': 'svn',
        'url': 'http://ncp-yamato.stanford.edu/svn/sample-repo'
    },
]

@task
def version(json, save):
    """
    Display the versions of nested repositories and exit.  UNIMPLEMENTED
    """
    pass

# options are accessed by virtualenv bootstrap command somehow.
options(
    virtualenv = Bunch(
        env_name = 'test_env',
        script_name = "bootstrap.py",
        packages_to_install = [
            "numpy",
            "scipy",
            "pygeoprocessing==0.2.2",
            "psycopg2"]
    )
)
@task
@cmdopts([
    ('system-site-packages', '', ('Give the virtual environment access '
                                     'to the global site-packages')),
])
def env(options):
    """
    Set up a virtualenv for the project.
    """

    # Detect whether the user called `paver env` with the system-site-packages
    # flag.  If so, modify the paver options object so that bootstrapping will
    # use the virtualenv WITH the system-site-packages linked in.
    try:
        use_site_pkgs = options.env.system_site_packages
    except AttributeError:
        use_site_pkgs = False
    options.virtualenv.system_site_packages = use_site_pkgs

    # Uses the options.virtualenv settings we set in the Option() call above
    # and with whatever other settings are modified before this call.
    paver.virtual.bootstrap()

    # Built the bootstrap env via a subprocess call.
    # Calling via the shell so that virtualenv has access to environment
    # vars as needed.
    env_dirname = options.virtualenv.env_name
    bootstrap_cmd = "%(python)s %(bootstrap_file)s %(env_name)s"
    bootstrap_opts = {
        "python": sys.executable,
        "bootstrap_file": options.virtualenv.script_name,
        "env_name": env_dirname,
    }
    err_code = sh(bootstrap_cmd % bootstrap_opts)
    if err_code != 0:
        print "ERROR: Environment setup failed.  See the log for details"
        return

    print '*** Virtual environment created successfully.'
    print '*** To activate the env, run:'
    if platform.system() == 'Windows':
        print r'    call .\%s\Scripts\activate' % env_dirname
    else:  # assume all POSIX systems behave the same way
        print '    source %s/bin/activate' % env_dirname

@task
@consume_args  # when consuuming args, it's a list of str arguments.
def fetch(args):
    """
    Clone repositories the correct locations.
    """

    # figure out which repos/revs we're hoping to update.
    # None is our internal, temp keyword representing the LATEST possible
    # rev.
    user_repo_revs = {}  # repo -> version
    repo_paths = map(lambda x: x['path'], REPOS)
    args_queue = collections.deque(args[:])

    while len(args_queue) > 0:
        current_arg = args_queue.popleft()

        # If the user provides repo revisions, it MUST be a specific repo.
        if current_arg in repo_paths:
            # the user might provide a revision.
            # It's a rev if it's not a repo.
            try:
                possible_rev = args_queue.popleft()
            except IndexError:
                # When no other args after the repo
                user_repo_revs[current_arg] = None
                continue

            if possible_rev in repo_paths:
                # then it's not a revision, it's a repo.  put it back.
                # Also, assume user wants the repo we're currently working with
                # to be updated to the tip OR whatever.
                user_repo_revs[current_arg] = None
                args_queue.appendleft(possible_rev)
                continue
            elif possible_rev in ['-r', '--rev']:
                requested_rev = args_queue.popleft()
                user_repo_revs[current_arg] = requested_rev
            else:
                print "ERROR: unclear arg %s" % possible_rev
                return

    # determine which groupings the user wants to operate on.
    # example: `src` would represent all repos under src/
    # example: `data` would represent all repos under data/
    # example: `src/pygeoprocessing` would represent the pygeoprocessing repo
    repos = set([])
    for argument in args:
        if not argument.startswith('-'):
            repos.add(argument)


    def _user_requested_repo(local_repo_path):
        """
        Check if the user requested this repository.
        Does so by checking prefixes provided by the user.

        Arguments:
            local_repo_path (string): the path to the local repository
                relative to the CWD. (example: src/pygeoprocessing)

        Returns:
            Boolean: Whether the user did request this repo.
        """
        # check that the user wants to update this repo
        for user_arg_prefix in repos:
            if local_repo_path.startswith(user_arg_prefix):
                return True
        return False

    for repo_dict in REPOS:
        LOGGER.debug('Checking %s', repo_dict['path'])

        # If the user did not request this repo AND the user didn't want to
        # update everything (by specifying no positional args), skip this repo.
        if not _user_requested_repo(repo_dict['path']) and len(repos) > 0:
            continue

        # does repo exist?  If not, clone it.
        repo = SCMS[repo_dict['scm']](repo_dict['path'], repo_dict['url'])
        if not repo.ischeckedout():
            repo.clone()
        else:
            LOGGER.debug('Repository %s exists', repo_dict['path'])

        # is repo up-to-date?  If not, update it.
        # If this is a dry run, jus print the command.
        # If the user specified a target revision, use that instead.
        try:
            target_rev = user_repo_revs[repo_dict['path']]
            if target_rev is None:
                raise KeyError
        except KeyError:
            target_rev = repo.tracked_version()

        repo.pull()
        repo.update(target_rev)

@task
@consume_args
def push(args):
    """Push a file or files to a remote server.

    Usage:
        paver push [--password] [user@]hostname[:target_dir] file1, file2, ...

    Uses pythonic paramiko-based SCP to copy files to the remote server.

    If --password is provided at the command line, the user will be prompted
    for a password.  This is sometimes required when the remote's private key
    requires a password to decrypt.

    If a target username is not provided ([user@]...), the current user's username
    used for the transfer.

    If a target directory is not provided (hostname[:target_dir]), the current
    directory of the target user is used.
    """
    import paramiko
    from paramiko import SSHClient
    from scp import SCPClient
    ssh = SSHClient()
    ssh.load_system_host_keys()

    # Clean out all of the user-configurable options flags.
    config_opts = []
    for argument in args:
        if argument.startswith('--'):
            config_opts.append(argument)
            _ = args.remove(argument)

    use_password = '--password' in config_opts

    try:
        destination_config = args[0]
    except IndexError:
        print "ERROR: destination config must be provided"
        return

    files_to_push = args[1:]
    if len(files_to_push) == 0:
        print "ERROR: At least one file must be given"
        return

    # ASSUME WE'RE ONLY DOING ONE HOST PER PUSH
    # split apart the configuration string.
    # format:
    #    [user@]hostname[:directory]
    if '@' in destination_config:
        username = destination_config.split('@')[0]
        destination_config = destination_config.replace(username + '@', '')
    else:
        username = getpass.getuser()

    if ':' in destination_config:
        target_dir = destination_config.split(':')[-1]
        destination_config = destination_config.replace(':' + target_dir, '')
    else:
        # just use the SCP default
        target_dir = None

    # hostname is whatever remains of the dest config.
    hostname = destination_config

    # start up the SSH connection
    if use_password:
        password = getpass.getpass()
    else:
        password = None

    try:
        ssh.connect(hostname, username=username, password=password)
    except paramiko.BadAuthenticationType:
        print 'ERROR: incorrect password or bad SSH key.'
        return
    except paramiko.PasswordRequiredException:
        print 'ERROR: password required to decrypt private key on remote.  Use --password flag'
        return

    scp = SCPClient(ssh.get_transport())
    for transfer_file in files_to_push:
        file_basename = os.path.basename(transfer_file)
        if target_dir is not None:
            target_filename = os.path.join(target_dir, file_basename)
        else:
            target_filename = file_basename

        print 'Transferring %s -> %s:%s ' % (transfer_file, hostname, target_filename)
        scp.put(transfer_file, target_filename)

@task
def clean(options):
    """
    Remove files and folders known to be generated by build scripts.
    """

    folders_to_rm = ['build', 'dist', 'tmp', 'bin', options.virtualenv.env_name]
    files_to_rm = [options.virtualenv.script_name]

    if platform.system() == 'Windows':
        rm_stmt = 'DEL /R %s'
    else:
        rm_stmt = 'rm -r %s'

    for folder in folders_to_rm:
        try:
            print rm_stmt % folder
            shutil.rmtree(folder)
        except OSError:
            pass

    for filename in files_to_rm:
        try:
            print rm_stmt % filename
            os.remove(filename)
        except OSError:
            pass

    # clean out all python package repos in src/
    for repodir in map(lambda x: x['path'], REPOS):
        if repodir.startswith('src'):
            os.chdir(repodir)
            print 'cd ' + repodir
            sh(sys.executable + ' setup.py clean')
            os.chdir('..')

@task
@cmdopts([
    ('force-dev', '', 'Zip subrepos even if their version does not match the known state')
])
def zip_source(options):
    """
    Create a zip archive of all source repositories for this project.

    Creates a standalone zip file that, when extracted, will contain all source code
    needed to create documentation and functional binaries from the various projects
    managed by this project.  If there's a source repo in this repository, its source
    is in this archive.

    If --force-dev is provided, the state of the contained subrepositories/subprojects
    is allowed to differ from the revision noted in versions.json.  If the state of
    the subproject/subrepository does not match the state noted in versions.json and
    --force-dev is NOT provided, an error will be raised.
    """
    sh('mkdir -p tmp/source')
    sh('hg archive tmp/invest-bin.zip')
    sh('unzip -o tmp/invest-bin.zip -d tmp/source')
    for dirname in map(lambda x: x['path'], REPOS):
        if not dirname[0:4] in ['doc', 'src']:
            continue
        projectname = dirname.replace('src/', '')
        sh('hg archive -R %(repo)s tmp/%(zipname)s.zip' % {
            'repo': dirname, 'zipname': projectname})

        sh('unzip -o tmp/%(zipname)s.zip -d tmp/source' % {'zipname': projectname})
        sh('cp -r tmp/source/%(project)s tmp/source/invest-bin/src/' % {
            'project': projectname})

    sh('cd tmp/source && zip -r ../../invest-source.zip invest-bin')

@task
def build_docs(options):
    """
    Build the sphinx user's guide for InVEST
    """
    guide_dir = os.path.join('doc', 'users-guide')
    latex_dir = os.path.join(guide_dir, 'build', 'latex')
    sh('make clean', cwd=guide_dir)
    sh('make html', cwd=guide_dir)
    sh('make latex', cwd=guide_dir)
    sh('make all-pdf', cwd=latex_dir)


