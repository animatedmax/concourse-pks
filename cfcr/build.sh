#!/usr/bin/env bash

set -e

# build the static app
cd docs-cfcr
mkdocs build

# push the static app to PWS
cd site

stty -echo
cf login -a api.run.pivotal.io -u $USERNAME -p $PASSWORD -o pivotal-pubtools -s pivotalcf-staging > /dev/null
stty echo

cf push docs-cfcr -b staticfile_buildpack
