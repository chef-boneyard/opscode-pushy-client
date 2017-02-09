#
# Copyright 2012-2015 Chef Software, Inc.
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

name "rbczmq"

default_version "089bb0029c35f26ef1ca6d9d4a3faf2db50a4c8c"

# license "MIT"
# license_file "LICENSE"
skip_transitive_dependency_licensing true

dependency "libzmq"
dependency "libsodium"
dependency "libczmq"
dependency "bundler"
#dependency "rake"
# Is libtool actually necessary? Doesn't configure generate one?
# dependency "libtool" unless windows?

# version("3.0.13") { source md5: "45f3b6dbc9ee7c7dfbbbc5feba571529" }
# version("3.2.1")  { source md5: "83b89587607e3eb65c70d361f13bab43" }

source git: "https://github.com/methodmissing/rbczmq.git"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  # Gemfile is locked json-1.8.1
  bundle "update json", env: env
  bundle "install", env: env
  # env["INSTALL"] = "/opt/freeware/bin/install" if aix?
  rake "compile:rbczmq_ext -- --with-system-libs", env: env
end
