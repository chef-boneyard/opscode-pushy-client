# Chef Push Client Changes
<!-- usage documentation: http://expeditor-docs.es.chef.io/configuration/changelog/ -->
<!-- latest_release unreleased -->
## Unreleased

#### Merged Pull Requests
- Bump minor to 2.5 [#156](https://github.com/chef/opscode-pushy-client/pull/156) ([btm](https://github.com/btm))
<!-- latest_release -->

<!-- release_rollup since=2.4.8 -->
### Changes since 2.4.8 release

#### Merged Pull Requests
- Bump minor to 2.5 [#156](https://github.com/chef/opscode-pushy-client/pull/156) ([btm](https://github.com/btm)) <!-- 2.5.0 -->
- expeditor config: bundle update every time [#155](https://github.com/chef/opscode-pushy-client/pull/155) ([lamont-granquist](https://github.com/lamont-granquist)) <!-- 2.4.11 -->
- refactor timeout on message send [#152](https://github.com/chef/opscode-pushy-client/pull/152) ([jeremymv2](https://github.com/jeremymv2)) <!-- 2.4.10 -->
- Optimize `get_config` by eliminating extensive retry behavior [#151](https://github.com/chef/opscode-pushy-client/pull/151) ([jeremymv2](https://github.com/jeremymv2)) <!-- 2.4.9 -->
<!-- release_rollup -->

<!-- latest_stable_release -->
## [2.4.8](https://github.com/chef/opscode-pushy-client/tree/2.4.8) (2018-02-05)

#### Merged Pull Requests
- Add CODEOWNERS file [#148](https://github.com/chef/opscode-pushy-client/pull/148) ([schisamo](https://github.com/schisamo))
- Add AIX support [#149](https://github.com/chef/opscode-pushy-client/pull/149) ([jeremiahsnapp](https://github.com/jeremiahsnapp))
- update dependency versions [#150](https://github.com/chef/opscode-pushy-client/pull/150) ([jaymalasinha](https://github.com/jaymalasinha))
<!-- latest_stable_release -->

## [2.4.5](https://github.com/chef/opscode-pushy-client/tree/2.4.5) (2017-11-03)

#### Merged Pull Requests
- Wrap ZMQ request in timeout [#143](https://github.com/chef/opscode-pushy-client/pull/143) ([nsdavidson](https://github.com/nsdavidson))

## [2.4.4](https://github.com/chef/opscode-pushy-client/tree/2.4.4) (2017-09-21)

#### Merged Pull Requests
- Update Expeditor config to meet 0.5.0 requirements [#142](https://github.com/chef/opscode-pushy-client/pull/142) ([tduffield](https://github.com/tduffield))
- Update ruby to 2.4.2 [#145](https://github.com/chef/opscode-pushy-client/pull/145) ([PrajaktaPurohit](https://github.com/PrajaktaPurohit))
- Updating bundler to 1.15.4. Some README updates. [#146](https://github.com/chef/opscode-pushy-client/pull/146) ([PrajaktaPurohit](https://github.com/PrajaktaPurohit))

## [2.4.1](https://github.com/chef/opscode-pushy-client/tree/2.4.1) (2017-08-16)

#### Merged Pull Requests
- Perform version bump on correct path [#134](https://github.com/chef/opscode-pushy-client/pull/134) ([schisamo](https://github.com/schisamo))
- Ensure version bump sed matches the correct line [#135](https://github.com/chef/opscode-pushy-client/pull/135) ([schisamo](https://github.com/schisamo))
- Update SHA1 fingerprint for MSI signing cert [#136](https://github.com/chef/opscode-pushy-client/pull/136) ([schisamo](https://github.com/schisamo))
- Update the CHANGELOG when push-client is promoted to stable [#137](https://github.com/chef/opscode-pushy-client/pull/137) ([tduffield](https://github.com/tduffield))
- Allow push jobs to build libzmq from source on windows [#128](https://github.com/chef/opscode-pushy-client/pull/128) ([ksubrama](https://github.com/ksubrama))
- Add Option to manage environment variables that could be overwritten  [#140](https://github.com/chef/opscode-pushy-client/pull/140) ([jaym](https://github.com/jaym))



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