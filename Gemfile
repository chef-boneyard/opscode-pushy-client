source :rubygems

gemspec

gem "mixlib-cli", "~> 1.2.2", :require => "mixlib/cli"
gem "mixlib-log", "~> 1.3.0", :require => "mixlib/log"
gem "chef", ">= 0.10.12"
gem "zmq"

platforms :mswin, :mingw do
  gem "ffi"
  gem "rdp-ruby-wmi"
  gem "windows-api"
  gem "windows-pr"
  gem "win32-api"
  gem "win32-dir"
  gem "win32-event"
  gem "win32-mutex"
  gem "win32-process", "~> 0.6.5"
  gem "win32-service"
end

platforms :mingw_18 do
  gem "win32-open3"
end

group :test do
  gem "rspec"
  gem 'rack'
  gem 'thin'
end
