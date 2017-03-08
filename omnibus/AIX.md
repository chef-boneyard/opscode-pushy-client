Building an AIX package
============================
What is this `aix` branch I found, you ask? Read on below to see! We made a long
lived branch so if we ever need to reproduce this one-off customer build we have
a starting place to do that. Hopefully we will not.

Background
------------
Building on AIX is hard. To get FFI building on that OS was more work
than we could commit to. To meet a customer need we decided to build a custom
C extension for the parts of ZeroMQ that we need.

We actually have a fairly small use case for ZMQ in Push Jobs Client. There are
two sockets, one subscriber and one dealer. The dealer needs to send encrypted
information to the server. That is basically it.

This small footprint led us to try writing a custom C extension using only the
parts of ZMQ that we need, instead of trying to get all of FFI working (the
way we leverage ZMQ on other systems).

RbZMQ
-----
We [forked](https://github.com/chef/rbzmq) an old C native extension of LibZMQ
and modified it to fit our needs. This meant ripping out any unused code and
updating only the methods we need (like `context.socket`) to support later
versions of Ruby and LibZMQ.

Future notes: I found it easiest to use the `rake compile` commands to test
compiling the native extension. Then `rake gem` will create a gem

LibZMQ
-----
To get LibZMQ building on AIX we needed to update from 4.0.5 to 4.2.2 because
it has autotools and build configuration improvements. We still encountered
two issues.

First, in [`tcp_connector.hpp`](https://github.com/chef/libzmq/blob/master/src/tcp_connecter.hpp#L87)
the `open` method was getting redefined to `open64` somehow. We do not understand
completely how it happened but it was a result of including `fcntl.h` on a large
format filesystem. See [this](https://www.ibm.com/support/knowledgecenter/ssw_aix_71/com.ibm.aix.basetrf1/open.htm).
To fix this compilation issue I renamed `open` to `openn` to keep it from
getting redefined.

Second, when trying to run libzmq and request a socket we were seeing failures
(resulting in core dumps) around the use of mutexes. We eventually narrowed
this down to the [`atomic_counter.hpp`](https://github.com/chef/libzmq/blob/master/src/atomic_counter.hpp).
This class has a bunch of overrides to support atomic operations using system
or compiler native features. As a fallback it would use a mutex to perform
atomic operations but we were seeing that mutex never be initialized. So we
added support for the built-in AIX atomic operations `fetch_and_add`.

Our changes are checked into the `master` branch of the [`chef/libzmq`](https://github.com/chef/libzmq)
project. I did not submit an upstream PR because the `tcp_connector` issue was
so weird.

Software Definitions
-----
We copied some software definitions from omnibus-software and embedded them
here. This allowed us, during development, to quickly iterate on these. They
currently also pin versions to some branches that may never get released/merged
so I decided to keep them around.

Reproducing the package
-----
As part of these changes you can see a new omnibus AIX build machine. Start this
WPAR with `kitchen converge aix` from the omnibus directory. This should get you
an AIX machine with the omnibus toolchain installed on it. Seek out the AIX
expert for the credentials necessary.

Once on the machine you will use the typical build omnibus kitchen-based build
instructions:

1. It is recommended to use `screen` for persisting work and `bash` because this is a reasonable shell
1. `su - vagrant` to become the build user.
  1. This user is probably missing sudo permissions (which are required). Add them to the `/etc/sudoers` file with password-less sudo permission
1. `source load-omnibus-toolchain.sh`
1. You will need to clone the source because there are not shared folders. `mkdir ~/code && cd code && and git clone https://github.com/chef/opscode-pushy-client`
1. `cd opscode-pushy-client && git checkout tball/aix` to get this branch
1. Before you can run a build you need to [setup github SSH keys](https://help.github.com/articles/connecting-to-github-with-ssh/)
1. `cd omnibus && bundle install && bundle exec omnibus build push-jobs-client`
  1. This will probably fail because some required folders are missing. Create them and set the owner to be the `vagrant` user.
  1. Because of the default partition sizes for our WPARs we set the omnibus build directory to `/opt/omnibus-toolchain/local`. See the `omnibus.rb` for details.
