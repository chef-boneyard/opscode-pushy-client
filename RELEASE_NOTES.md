# Push Jobs Client Release Notes

## 3.0

Versions of Chef Push Jobs 3.0 and later may only be used under the terms of the [Chef EULA](https://www.chef.io/end-user-license-agreement/) or another commercial agreement with Chef Software.

## Dependency updates
- Chef Infra Client 13.11.3 to 15.10.12

## Security updates

These updates include a large number of CVE fixes. Users are strongly encouraged to upgrade.

- Ruby 2.4.5 to 2.6.6
- libarchive 3.3.3 to 3.4.2
- libxml2 2.9.7 to 2.9.10
- libxslt 1.1.30 to 1.1.34
- openssl 1.0.2p to 1.0.2u

Added platform support:
- AIX 7.2
- Debian 9, 10
- RHEL 8
- macOS 10.15
- Ubuntu 16.04, 18.04, 20.04
- Windows Server 2016, 2019, 10

Removed EOL platform support:
- Debian 6, 7
- macOS 10.12
- RHEL 5
- Ubuntu 10.04, 12.04, 14.04
- Windows 7, 8, Server 2008r2

For more information see our [platform support policy](https://docs.chef.io/platforms/#platform-end-of-life-policy).

### experimental max\_body\_size setting

This release includes an experimental feature to increase the maximum body size of a message body between the client and server. The default size for the client remains 63kb.
This limit may be increased by using the `--max-body-size` option or setting ssss in the `/etc/chef/push-jobs-client.rb` configuration file. The limit must be passed as bytes, so to increase the limit to 80k, you would pass `--max-body-size 80000`.
You must use Push Jobs Server 3.0 or later to use this feature and set the max body size at least as large on the server. It is recommended to add 2k to the server value to leave room for the signature on the message.

## 2.4.9

This release ships with notable fixes for a long standing issue where the Client could become deadlocked after encoutering network disruptions communicating with the Server.

*Note*

Due to the nature of the fixes above we are eager to hear your feedback on _any_ changes obeserved from the typical behavior of previous Client versions!
