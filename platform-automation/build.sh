#!/usr/bin/env bash

set -e

export WORKSPACE_IN_CONTAINER=`pwd`

cd bookbinder-release-complete
tar xzf *.tar.gz

cd $WORKSPACE_IN_CONTAINER/docs-book-platform-automation

export BOOKBINDER=$WORKSPACE_IN_CONTAINER/bookbinder-release-complete/bookbinder/install_bin/bookbinder
export BUNDLE_GEMFILE=$WORKSPACE_IN_CONTAINER/bookbinder-release-complete/bookbinder/Gemfile

time bundle exec $BOOKBINDER bind local

cd final_app

stty -echo
cf login -a api.run.pivotal.io -u $USERNAME -p $PASSWORD -o pivotal-pubtools -s pivotalcf-staging > /dev/null
stty echo

cf push docs-platform-automation -b https://github.com/cloudfoundry/ruby-buildpack#v1.6.28
