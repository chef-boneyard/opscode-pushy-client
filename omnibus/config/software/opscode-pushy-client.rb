#
# Copyright:: Copyright (c) 2013-2019 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "opscode-pushy-client"

default_version "local_source"

license "Apache-2.0"
license_file "LICENSE"

# For the specific super-special version "local_source", build the source from
# the local git checkout. This is what you'd want to occur by default if you
# just ran omnibus build locally.
version("local_source") do
  source path: "#{project.files_path}/../..",
         # Since we are using the local repo, we try to not copy any files
         # that are generated in the process of bundle installing omnibus.
         # If the install steps are well-behaved, this should not matter
         # since we only perform bundle and gem installs from the
         # omnibus cache source directory, but we do this regardless
         # to maintain consistency between what a local build sees and
         # what a github based build will see.
         options: { exclude: [ "omnibus/vendor" ] }
end

# For any version other than "local_source", fetch from github.
if version != "local_source"
  source git: "https://github.com/chef/opscode-pushy-client.git"
end

relative_path "opscode-pushy-client"

# For nokogiri (via Chef)
# TODO: Move these deps into omnibus-software chef definition
dependency "libxml2"
dependency "libxslt"
dependency "libiconv"
dependency "liblzma"
dependency "libzmq"

# Core Requirements

# Instead of trying to get all of FFI working on AIX we decided to build a custom C extension for the parts of
# ZeroMQ that we need. We forked an old C native extension of LibZMQ, https://github.com/chef/rbzmq, and modified
# it to fit our needs. This meant ripping out any unused code and updating only the methods we need
# (like context.socket) to support later versions of Ruby and LibZMQ.
dependency "rbzmq" if aix?

dependency "rubygems"
dependency "bundler"
dependency "chef"
dependency "openssl-customization"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  bundle "install", env: env
  gem "build opscode-pushy-client.gemspec", env: env
  gem "install opscode-pushy-client*.gem" \
      " --no-doc --verbose", env: env

  appbundle 'opscode-pushy-client', env: env
end
