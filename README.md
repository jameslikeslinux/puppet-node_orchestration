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

### Puppet Enterprise Requirements

1. Define a `plan_hierarchy` in Hiera as described at
   https://www.puppet.com/docs/bolt/latest/hiera.html#outside-apply-blocks.
2. Create a new PE user role called "Inventory Manager" with the permissions
   from type "Nodes" with action "add and delete connection information from
   inventory service." Assign a new service account to this role and generate a
   long-lived API token for the account, such as with the command: `puppet
   access login --lifetime 1y --print`. Provide the token in the Hiera plan
   hierarchy under the key `node_orchestration::api_token`. EYAML is suggested.
3. Tell the plan where to run its tasks with the Hiera plan hierarchy key
   `node_orchestration::task_server`. This is the server where you declared the
   `node_orchestration::aws` class. If this differs from your main Puppet
   server, also set the `node_orchestrator::puppet_server` key so the plan
   knows against which server to bootstrap the new agent.

### AWS Requirements

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
2. Create the following AWS resources: SSH key pair (note name and private key
   content), named subnet (VPC subnets have no names out of the box), and one
   or more named security groups.
3. Somewhere in the Hiera plan hierarchy, define the following settings:
   ```yaml
   ---
   node_orchestration::ec2_key_name: 'the-key-name'
   node_orchestration::ec2_subnet: 'the-subnet-name'
   node_orchestration::ec2_security_groups: ['sg1', 'sg2', etc...]
   node_orchestration::ssh_private_key: >
     ENC[PKCS7,MII...the-eyaml-encrypted-private-key-contents]
   ```

### Azure Requirements

1. Create a new Enterprise Application object in the Azure Active Directory to
   represent this module. Take note of the resulting client ID and secret.
2. Create a new Resource Group and Virtual Network to contain the VMs managed
   by this module.
3. In the new Resource Group's access control (IAM) settings, add a
   "Contributor" role assignment for your new application principal. 
4. Declare the `node_orchestration::azure` class on your Puppet server to
   configure the Azure CLI for this module to use, like:
   ```puppet
   class { 'node_orchestration::azure':
     tenant_id     => 'ea383a66-fake-fake-fake-f3524734e142', # Active Directory ID
     client_id     => '6b7f97e9-fake-fake-fake-ad4c99440348',
     client_secret => Sensitive('the-secret-access-key'),
   }
   ```
5. Somewhere in the Hiera plan hierarchy, define the following settings:
   ```yaml
   ---
   node_orchestration::az_resource_group: 'ResourceGroupName' # that you created in step 2
   node_orchestration::az_admin_password: >
     ENC[PKCS7,MII...the-eyaml-encrypted-initial-virtual-machine-password]
   ```

### Beginning with node_orchestration

When the setup requirements are satisfied, the plans provided by this module
can be run from the PE console.

## Usage

### `node_orchestration::launch_ec2_instance`

Create an EC2 instance with default settings.

* `instance_name`: The name of the instance to create
* `size`: The type of instance to create (small, medium, large)
* `image_id`: Overrides the default AMI set in Hiera
* `ami_user`: Overrides the default AMI username set in Hiera
* `key_name`: Overrides the default SSH key name set in Hiera
* `public_ip_address`: Overrides Hiera setting on whether to assign a public IP
  address. Subnet default takes priority.
* `security_groups`: Overrides the default SG or list of SGs set in Hiera
* `subnet`: Overrides the default subnet name set in Hiera
* `region`: Overrides the default region set in Hiera
* `os_disk_size`: If set, the size of the OS disk in GB. Otherwise, use EC2 defaults.
* `role`: Set the `pp_role` extension request (trusted fact) to this value

The available sizes: small, medium, large; map to EC2 instance types t3.small,
t3.medium, and t3.large by default. This can be overridden with the
`node_orchestration::ec2_instance_types` Hiera plan data hash to provide
reasonable organization defaults. Likewise, many of the plan parameters can be
expressed as defaults in Hiera plan data.

### `node_orchestration::create_azure_vm`

Create an Azure VM with default settings.

* `vm_name`: The name of the VM to create
* `size`: The type of VM to create (small, medium, large)
* `image_id`: Overrides the default image ID set in Hiera
* `admin_user`: Overrides the initial VM username set in Hiera
* `admin_password`: Overrides the initial VM password set in Hiera
* `public_ip_address`: Overrides Hiera setting on whether to assign a public IP address
* `resource_group`: Overrides the resource group set in Hiera
* `os_disk_size`: If set, the size of the OS disk in GB. Otherwise, use Azure defaults.
* `data_disk_sizes`: The sizes of the data disks to attach in GB
* `role`: Set the `pp_role` extension request (trusted fact) to this value

The available sizes: small, medium, large; map to VM sizes Standard_B1s,
Standard_B2s, and Standard_D2s_v3 by default. This can be overridden with the
`node_orchestration::az_vm_sizes` Hiera plan data hash to provide reasonable
organization defaults. Likewise, many of the plan parameters can be expressed
as defaults in Hiera plan data.

## Limitations

This is a proof-of-concept module that provides basic support for AWS and
Azure. Not all the settings you might want to control are exposed, but the
plans as implemented aim to demonstrate various ways those settings can be
defined: as parameters, in module data, and Hiera. Implementations for other
cloud providers may look very different from these initial versions. Please
open an issue with features you'd like to see.

Support for Windows nodes has been tested in Azure but not EC2. In Azure,
bootstrapping a Windows node can be triggered by passing an `image_id`
containing `Win`, as all the Azure-provided Windows images have. This interface
is subject to change based on future development and feedback.
