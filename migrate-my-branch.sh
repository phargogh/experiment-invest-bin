#!/bin/bash
#
# Migrate my current state to a fork!
echo "What's your bitbucket username?"
read bitbucket_un
tbucket_un=jdouglass

echo "What's your bitbucket password?"
read -s bitbucket_password

echo "What would you like to name your repo fork?  Leave blank for 'invest-bin'"
read bitbucket_reponame
if [ "$bitbucket_reponame" = "" ]
then
    bitbucket_reponame="invest-bin"
fi

# create a fork of invest-py
wget https://api.bitbucket.org/1.0/repositories/jdouglass/invest-bin/fork \
    --post-data="name=${bitbucket_reponame}&language=python" \
    --user=$bitbucket_un \
    --password=$bitbucket_password \
    --auth-no-challenge \
    --output-document=fork.json

python -c "import json; print json.dumps(json.load(open('fork.json')), sort_keys=True, indent=4);"

