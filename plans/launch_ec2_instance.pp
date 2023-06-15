# Create an EC2 instance with default settings
#
# @param instance_name The name of the instance to create
# @param size The type of instance to create
# @param image_id Overrides the default AMI set in Hiera
# @param ami_user Overrides the default AMI username set in Hiera
# @param key_name Overrides the default SSH key name set in Hiera
# @param public_ip_address Overrides Hiera setting on whether to assign a public IP
#   address. Subnet default takes priority.
# @param security_groups Overrides the default SG or list of SGs set in Hiera
# @param subnet Overrides the default subnet name set in Hiera
# @param region Overrides the default region set in Hiera
# @param os_disk_size If set, the size of the OS disk in GB. Otherwise, use EC2 defaults.
plan node_orchestration::launch_ec2_instance (
  String $instance_name,
  Enum['small', 'medium', 'large'] $size,
  Optional[String] $image_id = undef,
  Optional[String] $ami_user = undef,
  Optional[String] $key_name = undef,
  Optional[Boolean] $public_ip_address = undef,
  Optional[Array[String]] $security_groups = undef,
  Optional[String] $subnet = undef,
  Optional[String] $region = undef,
  Optional[Integer] $os_disk_size = undef,
) {
  # Let defaults be defined in Hiera, overridden with parameters
  $real_image_id       = pick($image_id, lookup('node_orchestration::ec2_image_id', Optional[String], 'first', undef))
  $real_ami_user       = pick($ami_user, lookup('node_orchestration::ec2_ami_user', Optional[String], 'first', undef))
  $real_key_name       = pick($key_name, lookup('node_orchestration::ec2_key_name', Optional[String], 'first', undef))
  $real_public_ip_addr = pick($public_ip_address, lookup('node_orchestration::ec2_public_ip_address', Optional[Boolean], 'first', true))
  $real_sgs            = pick($security_groups, lookup('node_orchestration::ec2_security_groups', Optional[Array[String]], 'first', undef))
  $real_subnet         = pick($subnet, lookup('node_orchestration::ec2_subnet', Optional[String], 'first', undef))
  $real_region         = pick($region, lookup('node_orchestration::ec2_region', Optional[String], 'first', undef))

  $task_server     = lookup('node_orchestration::task_server', String)
  $instance_types  = lookup('node_orchestration::ec2_instance_types', Hash)

  unless $instance_types[$size] {
    fail("Size '${size}' not found in 'node_orchestration::ec2_instance_types' lookup hash")
  }

  if $os_disk_size {
    $block_devices = {
      device_name => '/dev/sda1',
      volume_size => $os_disk_size,
    }
  } else {
    $block_devices = undef
  }

  apply_prep($task_server)

  apply($task_server, '_description' => 'Create the instance') {
    ec2_instance { $instance_name:
      ensure                      => running,
      image_id                    => $real_image_id,
      instance_type               => $instance_types[$size],
      key_name                    => $real_key_name,
      region                      => $real_region,
      associate_public_ip_address => $real_public_ip_addr,
      security_groups             => $real_sgs,
      subnet                      => $real_subnet,
      block_devices               => $block_devices,
    }
  }

  $ip_address = Integer[0, 6].reduce(undef) |$result, $i| {
    if $result {
      break()
    }

    $check_cmd = shellquote('/opt/puppetlabs/bin/puppet', 'resource', '--to_yaml', 'ec2_instance', $instance_name)
    $resource = run_command($check_cmd, $task_server, 'Check if the instance is running', {
      _env_vars => { 'AWS_REGION' => $real_region },
    }).first.value['stdout'].parseyaml

    if $resource['ec2_instance'] and
        $resource['ec2_instance'][$instance_name] and
        $resource['ec2_instance'][$instance_name]['ensure'] == 'running' {
      log::info('Waiting for instance to finish booting')
      ctrl::sleep(20)

      if $real_public_ip_addr {
        $resource['ec2_instance'][$instance_name]['public_ip_address']
      } else {
        $resource['ec2_instance'][$instance_name]['private_ip_address']
      }
    } else {
      log::info('Instance is not running yet')
      ctrl::sleep(10)
    }
  }

  unless $ip_address {
    fail('Instance failed to launch within 60 seconds')
  }

  run_plan('node_orchestration::bootstrap_agent', {
    name     => $instance_name,
    hostname => $ip_address,
    user     => $real_ami_user,
  })
}
