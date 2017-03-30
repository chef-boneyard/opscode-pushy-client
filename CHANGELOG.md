# Chef Push Client Changes

## 2.2.0

* Update Ruby from 2.1.8 to 2.3.3
* Update Chef and Ohai dependencies to latest pre-Chef 13 releases

## 2.1.4

* Fix bug where a Job with STDOUT/STDERR too large for the server would cause Job to hang.
* Fix Ohai gem constraint causing fresh installations to break due to gem conflicts.

## 2.1.3

* Address exponential increase of client reconfigure threads when TCP ports 10000 and 443 become unavailable on the Push Jobs Server.

## 2.1.2

* Change sigkill handler to sigint

## 2.1.1

* Do not enforce 2.x reconfigure protocol on clients that have fallen back to 1.x protocols
* Don't fail installation if client doesn't start the first time (windows)
* De-restrict the win32-process gem

## 2.1.0

* Limited the zeromq high water mark to prevent buffering of heartbeats, which cause packet floods when the push-jobs-server restarts

## 2.0.1
* Fix Gemfile to use win32-process version compatible with chef 12.5

## 2.0.0

* Added curve based encryption for all ZeroMQ communication
* Added parameter/environment variable/file transfer support
* Added output capture
* Improve log output
* Added back compatibility to allow fall back to 1.0 server.
* Delay reconfiguration when a job is running.
* Added splay to reconfigure to protect against reconfigure stampedes.
* Added protocol version information
** Added support to detect some common failure cases
** Log windows service startup
* Config file path now searches ['chef-push-client.rb', 'push-jobs-client.rb', 'client.rb']
* Added print\_execution\_environment helper command
* Added push\_apply helper
* Updated to Chef 12.5.0

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
