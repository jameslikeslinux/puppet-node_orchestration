# Changelog

All notable changes to this project will be documented in this file.

## Release 0.1.0

Initial release.

**Features**

Provision basic nodes into AWS and Azure and bootstrap them with Puppet Agent.

**Bugfixes**

None.

**Known Issues**

The `launch_ec2_instance` plan depends on the deprecated
[`puppetlabs/aws`](https://forge.puppet.com/modules/puppetlabs/aws) module.
