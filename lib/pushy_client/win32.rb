#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

require 'win32/process'

module Process
  extend FFI::Library
  # Override WaitForSingleObject with :blocking => true, so that Process.wait
  # (from win32-process) will not block the Ruby interpreter while waiting for
  # the process to complete.
  ffi_lib :kernel32
  attach_function :WaitForSingleObject, [:ulong, :ulong], :ulong, :blocking => true
end
