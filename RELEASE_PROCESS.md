# Push Client Release Process

## Document Purpose

The purpose of this document is to describe the current release process such that any member of the team can do a release. As we improve the automation around the release process, the document should be updated such that it always has the exact steps required to release Push Client.

This document is NOT aspirational. We have a number of automation tools that we intend to use to improve the release release process; however, many are not fully integrated with our process yet.. Do not add them to this document until they are ready to be part of the release process and can be used by any team member to perform a release.

## Prequisites

In order to release, you will need the following accounts/permissions:

- Local checkouts of the opscode-pushy-client and chef-web-downloads repositories
- Push access to the opscode-pushy-client github repository
- Chef Software, Inc Slack account
- Account on [https://discourse.chef.io](https://discourse.chef.io) using your Chef email address
- VPN account for Chef Software, Inc.
- Login for manhattan.ci.chef.co (This is linked to your github
account.)
- Access to artifactory credentials (use your LDAP credentials)

## The Process

### Testing the release

Our current support platforms are as follows:

- Debian 6, 7
- Rhel 5, 6, 7
- Ubuntu 10.04, 12.04, 14.04
- Windows 7, 8, 8.1, 10, Server 2008 R2, 2012, 2012 R2

Currently, push-client must be manually tested to verify that it behaves correctly on its supported platforms. You can use the [push-setup](https://github.com/chef/oc-pushy-pedant/tree/master/dev/push-setup) script to easily set up a push-jobs-client + push-jobs-server cluster with the desired build versions that you'd like to test.

### Preparing the release

- [ ] Double check CHANGELOG.md to ensure it includes all included changes. Update as appropriate.

### Building and Releasing the Release

- [ ] Tag the opscode-pushy-client repository with the release version: `git
  tag -a VERSION_NUMBER`.

- [ ] Push the new tag: `git push origin master --tags`.

- [ ] Trigger a release build in Jenkins using the
  `push-jobs-client-trigger-release` trigger. Use the tag you created
  above as the GIT_REF parameter.
  - Watch the [push-jobs-client-trigger-release](http://manhattan.ci.chef.co/job/push-jobs-client-trigger-release/) build. (Need to be on VPN.)

- [ ] Wait for the pipeline to complete.
  - Once the build is complete, the packages will be in the [Artifactory omnibus-current-local repository](http://artifactory.chef.co/simple/omnibus-current-local/com/getchef/push-jobs-client/) (Need to be on VPN.)

- [ ] Use julia to promote the build: `@julia artifactory promote
  push-jobs-client TAG`.  Replace TAG with the Git tag you created in the opscode-pushy-client repo. Please do this in the
  "#eng-services-support" room.  Once this is done, the release is
  available to the public via the APT and YUM repositories.

- [ ] Chef employees should already know a release is coming; however, as a
  courtesy, drop a message in the #cft-announce slack channel that the release
  is coming. Provide the release number and any highlights of the release.

- [ ] In your local checkout of the [chef-web-downloads](https://github.com/chef/chef-web-downloads) repository,
generate an update to the download page using rake:

```
git checkout -b YOUR_INITIALS/release-push-jobs-client-VERSION
export ARTIFACTORY_USERNAME="Your LDAP username"
export ARTIFACTORY_PASSWORD="Your LDAP password"
rake fetch[push-jobs-client]
git add data/
# make sure all the changes are what you expect
# write a simple commit message
git commit -v
git push origin YOUR_INITIALS/release-push-jobs-client-VERSION
```

- [ ] Open a GitHub pull request for the chef-web-downloads repository
based on the branch you just created.

- [ ] Have someone review and approve the change by adding a comment to the PR: `@delivery approve`.
  - Once approved and committed to master, Delivery will deploy the change to [the acceptance Downloads page](https://downloads-acceptance.chef.io/push-jobs-client/).

- [ ] Once the change successfully completes the acceptance stage, verify the new release is visible on the acceptance Downloads page.

- [ ] Deliver the change by adding a comment to the PR: `@delivery deliver`.
  - Once Delivery is complete, the new release will be live on [the production Downloads page](http://downloads.chef.io/push-jobs-client/).

- [ ] Write and then publish a Discourse post on https://discourse.chef.io
  once the release is live. This post should contain a link to the downloads
  page ([https://downloads.chef.io](https://downloads.chef.io)) and its contents
  should be based on the information that was added to the RELEASE_NOTES.md file
  in an earlier step. *The post should  be published to the Chef Release
  Announcements category on https://discourse.chef.io. If it is a security
  release, it should also be published to the Chef Security Announcements
  category.* Full details on the policy of making release announcements on
  Discourse can be found on the wiki: [https://chefio.atlassian.net/wiki/display/ENG/Release+Announcements+and+Security+Alerts](https://chefio.atlassian.net/wiki/display/ENG/Release+Announcements+and+Security+Alerts)

- [ ] Let `#cft-announce` know about the release, including a link to the Discourse post.

Chef Push Jobs Client is now released.

## Post Release

- [ ] Relax 🎉
