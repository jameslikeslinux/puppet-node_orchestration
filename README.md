# node_orchestration

Tasks and plans for automatically provisioning cloud instances, registering
them to Puppet Enterprise, and bootstrapping Puppet agent on them.

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with node_orchestration](#setup)
    * [Setup requirements](#setup-requirements)
    * [Beginning with node_orchestration](#beginning-with-node_orchestration)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)

## Description

This module wraps low-level automation for cloud providers to provide
reasonable default settings and a simple user interface to create new nodes in
Puppet Enterprise. The plans provided in this module will launch an instance,
register it with the PE inventory service, and bootstrap Puppet agent on the
new node. By looking up common organization settings from Hiera, consistency
among the nodes managed by this automation is ensured. Puppet Orchestrator also
provides granular access control that can eliminate the need for direct user
access to the cloud providers.

## Setup

### Setup Requirements

1. Create an IAM user with the `AmazonEC2FullAccess` policy. This policy is
   sufficient, but not necessarily required. There may be a reduced set of
   privileges that can be associated with this user. Create an access key for
   this user. Pass the key information to the `node_orchestration::aws` class
   which you should declare on your Puppet server, like:
   ```puppet
   class { 'node_orchestration::aws':
     access_key_id     => 'AKIASUQFAKEACCESSKEY',
     secret_access_key => Sensitive('the-secret-access-key'),
     region            => 'us-east-1', # the default region to interact with
   }
   ```
   These values can of course be set in Hiera.
2. Define a `plan_hierarchy` in Hiera as described at
   https://www.puppet.com/docs/bolt/latest/hiera.html#outside-apply-blocks.
3. Create the following AWS resources: SSH key pair (note name and private key
   content), named subnet (VPC subnets have no names out of the box), and one
   or more named security groups.
4. Somewhere in the Hiera plan hierarchy, define the following settings:
   ```yaml
   ---
   node_orchestration::ec2_key_name: 'the-key-name'
   node_orchestration::ec2_subnet: 'the-subnet-name'
   node_orchestration::ec2_security_groups: ['sg1', 'sg2', etc...]
   node_orchestration::ssh_private_key: >
     ENC[PKCS7,MII...the-eyaml-encrypted-private-key-contents]
   ```
5. Create a new PE user role called "Inventory Manager" with the permissions
   from type "Nodes" with action "add and delete connection information from
   inventory service." Assign a new service account to this role and generate a
   long-lived API token for the account, such as with the command: `puppet
   access login --lifetime 1y --print`. Provide the token in the Hiera plan
   hierarchy under the key `node_orchestration::api_token`. EYAML is suggested.
6. Tell the plan where to run its tasks with the Hiera plan hierarchy key
   `node_orchestration::task_server`. This is the server where you declared the
   `node_orchestration::aws` class. If this differs from your main Puppet
   server, also set the `node_orchestrator::puppet_server` key so the plan
   knows against which server to bootstrap the new agent.

### Beginning with node_orchestration

When the setup requirements are satisfied, the plans provided by this module
can be run from the PE console.

## Usage

### `node_orchestration::launch_ec2_instance`

Create an EC2 instance with default settings.

* `name`: The name of the instance to create
* `size`: The type of instance to create (small, medium, large)
* `image_id`: Overrides the default AMI set in Hiera
* `ami_user`: Overrides the default AMI username set in Hiera
* `key_name`: Overrides the default SSH key name set in Hiera
* `security_groups`: Overrides the default SG or list of SGs set in Hiera
* `subnet`: Overrides the default subnet name set in Hiera
* `region`: Overrides the default region set in Hiera

The available sizes: small, medium, large; map to EC2 instance types t3.small,
t3.medium, and t3.large by default. This can be overridden with the
`node_orchestration::ec2_instance_types` Hiera plan data hash to provide
reasonable organization defaults. Likewise, many of the plan parameters can be
expressed as defaults in Hiera plan data.

## Limitations

This is a proof-of-concept module that provides basic support for EC2. Not all
the EC2 settings you might want to control are exposed, but the plans as
implemented aim to demonstrate various ways those settings can be defined: as
parameters, in module data, and Hiera. Implementations for other cloud
providers may look very different from this initial EC2 version.
