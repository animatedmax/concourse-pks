#!/bin/bash

set -ex

ROOT=`pwd`

cd bookbinder-release

tar xzf source.tar.gz
mv pivotal-cf-bookbinder-* bookbinder
cd bookbinder

if [ -f ${ROOT}/bookbinder-release-bundle/*.tar.gz ]; then
  mkdir -p vendor
  tar xzf ${ROOT}/bookbinder-release-bundle/*.tar.gz -C vendor
fi

bundle install --jobs=3 --retry=3 --path vendor/bundle --binstubs vendor/bundle/bin
bundle clean

cd ${ROOT}/bundle_output
tar czf bookbinder-release-complete.tar.gz -C ../bookbinder-release bookbinder
tar czf bookbinder-release-bundle.tar.gz -C ../bookbinder-release/bookbinder/vendor bundle
