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

name          "push-jobs-client"
friendly_name "Push Jobs Client"
maintainer    "Chef Software, Inc. <maintainers@chef.io>"
homepage      "https://www.chef.io"

license "Apache-2.0"
license_file "LICENSE"

# Ensure we install over the top of the previous package name
replace  "opscode-push-jobs-client"
conflict "opscode-push-jobs-client"

build_version IO.read(File.expand_path("../../../../VERSION", __FILE__)).strip

# In order to prevent unecessary cache expiration, version overrides
# and build_iteration are kept in <project-root>/omnibus_overrides.rb
overrides_path = File.expand_path("../../../../omnibus_overrides.rb", __FILE__)
instance_eval(IO.read(overrides_path), overrides_path)

if windows?
  # NOTE: Ruby DevKit fundamentally CANNOT be installed into "Program Files"
  #       Native gems will use gcc which will barf on files with spaces,
  #       which is only fixable if everyone in the world fixes their Makefiles
  install_dir  "#{default_root}/opscode/#{name}"
else
  install_dir "#{default_root}/#{name}"
end

dependency "preparation"
dependency "rb-readline"
dependency "opscode-pushy-client"
dependency "version-manifest"
dependency "clean-static-libs"
dependency "ruby-cleanup"

package :rpm do
  signing_passphrase ENV['OMNIBUS_RPM_SIGNING_PASSPHRASE']
  compression_level 1
  compression_type :xz
end

package :deb do
  compression_level 1
  compression_type :xz
end

package :pkg do
  identifier "com.getchef.pkg.push-jobs-client"
  signing_identity "Developer ID Installer: Chef Software, Inc. (EU3VF8YLX2)"
end
compress :dmg

package :msi do
  fast_msi true
  # Upgrade code for Chef MSI
  upgrade_code "D607A85C-BDFA-4F08-83ED-2ECB4DCD6BC5"
  signing_identity "E05FF095D07F233B78EB322132BFF0F035E11B5B", machine_store: true

  parameters(
    ProjectLocationDir: 'push-jobs-client',
    # We are going to use this path in the startup command of chef
    # service. So we need to change file seperators to make windows
    # happy.
    PushJobsGemPath: windows_safe_path(gem_path("opscode-pushy-client-[0-9]*")),
  )
end
