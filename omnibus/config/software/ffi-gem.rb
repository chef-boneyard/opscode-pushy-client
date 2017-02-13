#
# Copyright 2012-2014 Chef Software, Inc.
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

name "ffi-gem"
default_version "1.9.17"

license "BSD"
license_file "https://github.com/ffi/ffi/blob/master/LICENSE"

source git: "git@github.com:ffi/ffi.git"

dependency "ruby"
dependency "bundler"
#dependency "rake"

build do
  env = with_standard_compiler_flags(with_embedded_path)

  bundle "install", env: env
  bundle "exec rake install", env: env
end
