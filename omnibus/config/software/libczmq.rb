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

name "libczmq"

default_version "4.0.2"

# license "MIT"
# license_file "LICENSE"
skip_transitive_dependency_licensing true

# Is libtool actually necessary? Doesn't configure generate one?
# dependency "libtool" unless windows?

version("4.0.2") { source md5: "b27cb5a23c472949b1e37765e404dc98" }

source url: "https://github.com/zeromq/czmq/releases/download/v#{version}/czmq-#{version}.tar.gz"

relative_path "czmq-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  command "./configure" \
        " --prefix=#{install_dir}/embedded", env: env

  make "-j #{workers}", env: env
  make "install -j #{workers}", env: env
end
