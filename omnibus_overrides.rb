build_iteration 1

# Using pins that agree with chef 14.10.9.
override :chef,           version: "v14.11.21"
override :ohai,           version: "v14.8.10"

override :bundler,        version: "1.17.3"
override :rubygems,       version: "2.7.8"
override :ruby,           version: "2.5.3"

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
