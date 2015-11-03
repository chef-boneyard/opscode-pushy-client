# Chef Push Client Changes

## 1.3.4
* Add wait so that periodic reconfiguration doesn't kill running jobs

## 1.3.3
* Fixes to windows service to include multiple config files
* Search for config files in multiple places
* Check if DNS resolution works and log if not
* Logging enhancements

## 1.3.1

* Bump version to avoid semver issues with non-compliant 1.3.0.rc.0 tag

## 1.3.0 

* Move to ZeroMQ 4 and ffi-rzmq.
* Update Chef to 12.0
* Unlock Ohai to be free to track Chef
* Pull in latest omnibus-software including new OpenSSL

## 1.2.X - 2015-06-20 Botched version

## 1.1.2 - 2014-07-23

* Fix issue where Windows service was not being installed
* Fix issue where Windows service would not start

## 1.1.1 - 2014-06-13

* Adjust plugin loading for Ohai 7

* Fix signal handling to work under windows

## 1.0.1 - 2014-04-09

* Add require with rescue for chef/config_fetcher needed for compatibility with
  Chef >= 11.8.0.

* Add signal handling for the client. The client now does a graceful
  shutdown when it receives a `TERM`, `QUIT`, or `KILL` signal. The
  client will reconfigure itself if sent `USR1`. This improves the
  compatibility of the push client to be managed under runit which
  sends signals for restart.

* Add Apache 2 license and headers in preparation for open sourcing.

* Unify gem and repo tag versioning scheme.

