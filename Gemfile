source 'https://rubygems.org'

gemspec

group :docs do
  gem "yard"
end

group :omnibus_package do
  gem "appbundler"
end

platforms :mswin, :mingw do
  gem "ffi"
  gem "rdp-ruby-wmi"
  gem "windows-pr"
  gem "win32-api"
  gem "win32-dir"
  gem "win32-event"
  gem "win32-mutex"
  gem "win32-process", ">= 0.8.2"
  gem "win32-service"
end

platforms :mingw_18 do
  gem "win32-open3"
end
