#!/bin/bash

set -ex

ROOT=`pwd`

cd bookbinder

if [ -f ${ROOT}/bookbinder-bundle/*.tar.gz ]; then
  mkdir -p vendor
  tar xzf ${ROOT}/bookbinder-bundle/*.tar.gz -C vendor
fi

bundle install --jobs=3 --retry=3 --path vendor/bundle --binstubs vendor/bundle/bin
bundle clean

bundle exec rake

cd ${ROOT}/bundle_output
tar czf bookbinder-master-complete.tar.gz -C ${ROOT} bookbinder
tar czf bookbinder-bundle.tar.gz -C ${ROOT}/bookbinder/vendor bundle
