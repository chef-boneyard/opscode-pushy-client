# Push Jobs Client

[![Build Status](https://travis-ci.org/chef/opscode-pushy-client.svg?branch=master)](https://travis-ci.org/chef/opscode-pushy-client)

Want to find out more about Push Jobs? Check out [docs.chef.io](https://docs.chef.io/push_jobs.html)!

## Development
### Setup Local Machine

    bundle install
    brew install zeromq

### Setup Chef Server w/ Push Jobs Server
1. Check out chef/chef-server and start DVM w/ Manage and Push Jobs.
```yaml
# config.yml
vm:
  plugins:
    chef-manage: true
    push-jobs-server: true
```
Run `vagrant up` to bring up the Push Jobs Server.

2. Register you local machine as a node on the chef-server. From `chef-server/dev`, run:
```shell
vagrant ssh
sudo chef-server-ctl user-create local-dev Local Dev local@chef.io 'password' -f /installers/local-dev.pem
sudo chef-server-ctl org-create push-client-local "Local Push Client Development" -a local-dev -f /installers/push-client-local-validator.pem
```

3. Add your local machine as a node on the Chef Server.
```shell
chef-client -c .chef/client.rb
```

### Start Push Jobs Client
```shell
./bin/pushy-client -c .chef/push-jobs-client.rb
```

## Contributing

For information on contributing to this project see <https://github.com/chef/chef/blob/master/CONTRIBUTING.md>
