# Create an EC2 instance with default settings
#
# @param name The name of the instance to create
# @param size The type of instance to create
# @param image_id Overrides the default AMI set in Hiera
# @param ami_user Overrides the default AMI username set in Hiera
# @param key_name Overrides the default SSH key name set in Hiera
# @param security_groups Overrides the default SG or list of SGs set in Hiera
# @param subnet Overrides the default subnet name set in Hiera
# @param region Overrides the default region set in Hiera
plan node_orchestration::launch_ec2_instance (
  String $name,
  Enum['small', 'medium', 'large'] $size,
  Optional[String] $image_id = undef,
  Optional[String] $ami_user = undef,
  Optional[String] $key_name = undef,
  Optional[Variant[String, Array[String]]] $security_groups = undef,
  Optional[String] $subnet   = undef,
  Optional[String] $region   = undef,
) {
  # Let defaults be defined in Hiera, overridden with parameters
  $real_image_id = pick($image_id, lookup('node_orchestration::ec2_image_id', Optional[String], 'first', undef))
  $real_ami_user = pick($ami_user, lookup('node_orchestration::ec2_ami_user', Optional[String], 'first', undef))
  $real_key_name = pick($key_name, lookup('node_orchestration::ec2_key_name', Optional[String], 'first', undef))
  $real_sgs      = pick($security_groups, lookup('node_orchestration::ec2_security_groups', Optional[Variant[String, Array[String]]], 'first', undef))
  $real_subnet   = pick($subnet, lookup('node_orchestration::ec2_subnet', Optional[String], 'first', undef))
  $real_region   = pick($region, lookup('node_orchestration::ec2_region', Optional[String], 'first', undef))

  $task_server     = lookup('node_orchestration::task_server', String)
  $puppet_server   = lookup('node_orchestration::puppet_server', String, 'first', $task_server)
  $api_token       = lookup('node_orchestration::api_token', String)
  $ssh_private_key = lookup('node_orchestration::ssh_private_key', String)
  $instance_types  = lookup('node_orchestration::ec2_instance_types', Hash)

  unless $instance_types[$size] {
    fail("Size '${size}' not found in 'node_orchestration::ec2_instance_types' lookup hash")
  }

  run_task('aws::create_instance', $task_server, 'Create the instance', {
    image_id        => $real_image_id,
    instance_type   => $instance_types[$size],
    key_name        => $real_key_name,
    name            => $name,
    region          => $real_region,
    security_groups => $real_sgs,
    subnet          => $real_subnet,
  })

  $hostname = Integer[0, 6].reduce(undef) |$result, $i| {
    if $result {
      break()
    }

    $resource = run_command("/opt/puppetlabs/bin/puppet resource --to_yaml ec2_instance ${name.shellquote}", $task_server, 'Check if the instance is running', {
      _env_vars => { 'AWS_REGION' => $real_region },
    }).first.value['stdout'].parseyaml

    if $resource['ec2_instance'] and $resource['ec2_instance'][$name] and $resource['ec2_instance'][$name]['ensure'] == 'running' {
      log::info('Waiting for instance to finish booting')
      ctrl::sleep(20)
      $resource['ec2_instance'][$name]['public_dns_name']
    } else {
      log::info('Instance is not running yet')
      ctrl::sleep(10)
    }
  }

  unless $hostname {
    fail('Instance failed to launch within 60 seconds')
  }

  $type_header = 'Content-Type: application/json'
  $auth_header = "X-Authentication: ${api_token}"
  $uri = 'https://localhost:8143/inventory/v1/command/create-connection'
  $connection_config = {
    'certnames'            => [$name],
    'type'                 => 'ssh',
    'parameters'           => {
      'user'     => $real_ami_user,
      'run-as'   => 'root',
      'hostname' => $hostname,
    },
    'sensitive_parameters' => {
      'private-key-content' => $ssh_private_key,
    },
    'duplicates'           => 'replace',
  }.to_json

  run_command("/usr/bin/curl --insecure --header ${type_header.shellquote} --header ${auth_header.shellquote} --request POST ${uri.shellquote} --data ${connection_config.shellquote}", $task_server, 'Register inventory connection to the new instance')

  run_task('pe_bootstrap', $name, 'Bootstrap the Puppet agent', {
    certname => $name,
    server   => $puppet_server,
  })
}
