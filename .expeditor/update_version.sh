#!/bin/bash
#
# After a PR merge, Chef Expeditor will bump the PATCH version in the VERSION file.
# It then executes this file to update any other files/components with that new version.
#

set -evx

sed -i -r "s/^(\s*)VERSION = \".+\"/\1VERSION = \"$(cat VERSION)\"/" lib/pushy_client/version.rb

# Ensure our Gemfile.lock reflects the new version
#bundle update opscode-pushy-client
# XXX: for now we update everything continuously because bundler is buggy
bundle update
