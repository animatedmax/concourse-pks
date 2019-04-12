#!/bin/bash

set -ex

cd concourse-scripts

if [ -f ../concourse-scripts-bundle/*.tar.gz ]; then
  mkdir -p vendor
  tar xzf ../concourse-scripts-bundle/*.tar.gz -C vendor
fi

bundle install --jobs=3 --retry=3 --path vendor/bundle --binstubs vendor/bundle/bin --deployment
bundle clean

cd ../bundle_output
tar czf bundle.tar.gz -C ../concourse-scripts/vendor bundle
