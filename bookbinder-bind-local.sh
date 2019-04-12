#!/bin/bash

set -ex

export WORKSPACE_IN_CONTAINER=`pwd`

cd bookbinder-release
tar xzf *.tar.gz

cd $WORKSPACE_IN_CONTAINER/book

export BOOKBINDER=$WORKSPACE_IN_CONTAINER/bookbinder-release/bookbinder/install_bin/bookbinder
export BUNDLE_GEMFILE=$WORKSPACE_IN_CONTAINER/bookbinder-release/bookbinder/Gemfile

time bundle exec $BOOKBINDER bind local --require-valid-subnav-links

cd ../bind_output
tar czf final_app.tar.gz -C ../book final_app
