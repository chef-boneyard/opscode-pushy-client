build_iteration 1

override :chef,           version: "v15.10.12"
override :ohai,           version: "v15.9.1"

override :ruby,           version: "2.6.6"
override :rubygems,       version: "3.0.3"
override :bundler,        version: "1.17.2"

override :libxml2,        version: "2.9.10"
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
