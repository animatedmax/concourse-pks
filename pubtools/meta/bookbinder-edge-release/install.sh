#!/bin/bash

set -ex

ROOT=`pwd`

cd bookbinder

bundle install --jobs=3 --retry=3 --path vendor/bundle --binstubs vendor/bundle/bin
bundle clean

cd ${ROOT}/bundle_output
tar czf bookbinder-edge-release-complete.tar.gz -C .. bookbinder
