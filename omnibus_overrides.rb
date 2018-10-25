build_iteration 1

# Using pins that agree with chef 13.0.118.
override :chef,           version: "v13.4.24"
override :ohai,           version: "v13.0.1"

# Need modern bundler if we wish to support x-plat Gemfile.lock.
# Unfortunately, 1.14.x series has issues with BUNDLER_VERSION variables exported by
# the omnibus cookbook. Bump to it after the builders no longer set that environment
# variable.
override :bundler,        version: "1.15.4"
override :rubygems,       version: "2.7.6"
override :ruby,           version: "2.4.4"

override "libxml2", version: "2.9.7"
# Default in omnibus-software was too old.  Feel free to move this ahead as necessary.
override :libsodium,      version: "1.0.12"
if aix?
  # To get LibZMQ building on AIX we needed to update to 4.2.2 because it has autotools and
  # build configuration improvements.
  override :libzmq,         version: "4.2.2"
else
  # Pick last version in 4.0.x that we have tested on windows.
  # Feel free to bump this if you're willing to test out a newer version.
  override :libzmq,         version: "4.0.7"
end
override "libtool", version: "2.4.2"
