#!/bin/bash

set -ex

ROOT=`pwd`

cd testbb-release

tar xzf source.tar.gz
mv animatedmax-bookbinder-* testbb
cd testbb

if [ -f ${ROOT}/testbb-release-bundle/*.tar.gz ]; then
  mkdir -p vendor
  tar xzf ${ROOT}/testbb-release-bundle/*.tar.gz -C vendor
fi

bundle install --jobs=3 --retry=3 --path vendor/bundle --binstubs vendor/bundle/bin
bundle clean

cd ${ROOT}/bundle_output
tar czf testbb-release-complete.tar.gz -C ../testbb-release testbb
tar czf testbb-release-bundle.tar.gz -C ../testbb-release/testbb/vendor bundle
