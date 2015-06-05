import os
import logging
import sys
import json
import subprocess
import platform

import hglib
import paver.virtual
import paver.svn
from paver.easy import *

LOGGER = logging.getLogger('invest-bin')
_SDTOUT_HANDLER = logging.StreamHandler(sys.stdout)
_SDTOUT_HANDLER.setLevel(logging.INFO)
LOGGER.addHandler(_SDTOUT_HANDLER)


SCM_DATA = {
    'hg': {
        'statedir': '.hg',
        'clone': lambda s, d: hglib.clone(s, d),
        'update': lambda d, r: hglib.open(d).update(r),
    },
    'svn': {
        'statedir': '.svn',
        'clone': lambda s, d: paver.svn.checkout(s, d),
        'update': lambda d, r: paver.svn.update(d, r),
    }
}


REPOS = [
    {
        'path': 'src/pygeoprocessing',
        'scm': 'hg',
        'url': 'http://bitbucket.org/richpsharp/pygeoprocessing',
    },
    {
        'path': 'data/invest-data',
        'scm': 'svn',
        'url': 'http://ncp-yamato.stanford.edu/svn/sample-repo'
    },
]

@task
def version(json, save):
    pass

# options are accessed by virtualenv bootstrap command somehow.
options(
    virtualenv = Bunch(
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
    env_dirname = 'test_env'
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
    Download data to the correct location.
    """

    do_dry_run = '--dry-run' in args

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
        scm = SCM_DATA[repo_dict['scm']]
        repo_state_dir = os.path.join(repo_dict['path'], scm['statedir'])
        if not os.path.exists(repo_state_dir):
            print 'cloning %s' % repo_dict['path']
            scm['clone'](repo_dict['url'], repo_dict['path'])
        else:
            LOGGER.debug('Repository %s exists', repo_dict['path'])

        # is repo up-to-date?  If not, update it.
        print 'Updating %s' % repo_dict['path']
        target_rev = json.load(open('versions.json'))[repo_dict['path']]
        scm['update'](repo_dict['path'], target_rev)



