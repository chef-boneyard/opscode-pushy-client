# Push Jobs Client

[![Build Status](https://travis-ci.org/chef/opscode-pushy-client.svg?branch=master)](https://travis-ci.org/chef/opscode-pushy-client)

**Umbrella Project**: [Chef Infra](https://github.com/chef/chef-oss-practices/blob/master/projects/chef-server-infra.md)

**Project State**: [Active](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md#maintained)

**Issues [Response Time Maximum](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md)**: 28 days

**Pull Request [Response Time Maximum](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md)**: 28 days

NOTE: we know we have a backlog, and are working through it, but this applies for new requests.

This repository is the central repository for the Chef Push Jobs Client

If you want to file an issue about Chef Push Jobs Client or contribute a change, you're in the right place.

If you need to file an issue against another Chef project, you can find a list of projects and where to file issues in the [community contributions section](https://docs.chef.io/community_contributions.html#issues-and-bug-reports) of the [Chef docs](https://docs.chef.io).

Want to find out more about Push Jobs? Check out [docs.chef.io](https://docs.chef.io/push_jobs.html)!

## Getting Help

We use GitHub issues to track bugs and feature requests. If you need help please post to our Mailing List or join the Chef Community Slack.

 * Chef Community Slack at http://community-slack.chef.io/.
 * Chef Mailing List https://discourse.chef.io/

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
