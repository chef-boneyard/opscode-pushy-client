#
# Copyright 2012-2017 Chef Software, Inc.
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

# Copied from the omnibus-software definition because it is much easier to
# make changes in here. If our AIX changes are accepted into upstream we
# could use whatever version releases with those changes (potentially).
name "libzmq"
default_version "4.2.2"

license "LGPL-3.0"
license_file "COPYING"
license_file "COPYING.LESSER"

dependency "autoconf"
dependency "automake"
dependency "libtool"
dependency "pkg-config-lite"

version "4.2.2" do
  source md5: "52499909b29604c1e47a86f1cb6a9115",
    url: "https://github.com/zeromq/libzmq/releases/download/v#{version}/zeromq-#{version}.tar.gz"
  dependency "libsodium"
end

version "master" do
  source git: "git@github.com:tyler-ball/libzmq.git"
  dependency "libsodium"
end

relative_path "zeromq-#{version}"

build do
  env = with_standard_compiler_flags(with_embedded_path)
  env["CXXFLAGS"] = "-L#{install_dir}/embedded/lib -I#{install_dir}/embedded/include"

  # centos 5 has an old version of gcc (4.2.1) that has trouble with
  # long long and c++ in pedantic mode
  # This patch is specific to zeromq4
  if version == "master" || version.satisfies?(">= 4")
    patch source: "zeromq-4.0.5_configure-pedantic_centos_5.patch", env: env if el?
  end

  # TODO can we get rid of these and have it still work?
  # if aix?
  #   env['CXXFLAGS'] += " -g"
  #   env['CFLAGS'] += " -g"
  #   env['CPPFLAGS'] = env['CFLAGS']
  # end

  command "./autogen.sh", env: env
  cmd = [
    "./configure",
    # "--enable-shared", # TODO ????? needed? Should be defaulted
    "--with-libsodium=yes",
    "--disable-perf",
    "--disable-curve-keygen",
    "--without-docs",
    "ac_cv_func_mkdtemp=no",
    "--prefix=#{install_dir}/embedded"
  ]

  command cmd.join(" "), env: env

  make "-j #{workers}", env: env
  make "-j #{workers} install", env: env
end
