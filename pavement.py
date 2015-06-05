import os
import logging
import sys
import json

import hglib
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

@task
def fetch():
    """
    Download data to the correct location.
    """

    for repo_dict in REPOS:
        print 'checking %s' % repo_dict['path']
        LOGGER.debug('Checking %s', repo_dict['path'])
        # does repo exist?  If not, clone it.
        scm = SCM_DATA[repo_dict['scm']]
        repo_state_dir = os.path.join(repo_dict['path'], scm['statedir'])
        if not os.path.exists(repo_state_dir):
            scm['clone'](repo_dict['url'], repo_dict['path'])
        else:
            LOGGER.debug('Repository %s exists', repo_dict['path'])

        # is repo up-to-date?  If not, update it.
        target_rev = json.load(open('versions.json'))[repo_dict['path']]
        scm['update'](repo_dict['path'], target_rev)


