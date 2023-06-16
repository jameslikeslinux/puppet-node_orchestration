# Register a new node in the PE inventory and run pe_bootstrap against it
#
# @param name The desired node certname
# @param hostname The real hostname or IP address of the node to bootstrap
# @param user The SSH user to bootstrap with
#
# @api private
plan node_orchestration::bootstrap_agent (
  String $name,
  Stdlib::Host $hostname,
  Enum['ssh', 'winrm'] $connection_type,
  String $user,
  Optional[Sensitive] $password = undef,
  Optional[String] $role = undef,
) {
  $task_server   = lookup('node_orchestration::task_server', String)
  $puppet_server = lookup('node_orchestration::puppet_server', String, 'first', $task_server)
  $api_token     = lookup('node_orchestration::api_token', String)

  if $password {
    $sensitive_parameters = {
      'password' => $password.unwrap,
    }
  } elsif $connection_type == 'ssh' {
    $sensitive_parameters = {
      'private-key-content' => lookup('node_orchestration::ssh_private_key', String),
    }
  } else {
    fail("Password is required for connection type '${connection_type}'")
  }

  $type_header = 'Content-Type: application/json'
  $auth_header = "X-Authentication: ${api_token}"
  $uri = 'https://localhost:8143/inventory/v1/command/create-connection'

  $connection_config = {
    'certnames'            => [$name],
    'type'                 => $connection_type,
    'parameters'           => {
      'user'     => $user,
      'run-as'   => 'root',
      'hostname' => $hostname,
    },
    'sensitive_parameters' => $sensitive_parameters,
    'duplicates'           => 'replace',
  }.to_json

  $curl_command = [
    '/usr/bin/curl', '--insecure',
    '--header', $type_header,
    '--header', $auth_header,
    '--request', 'POST', $uri,
    '--data', $connection_config,
  ].shellquote

  run_command($curl_command, $task_server, 'Register inventory connection to the new instance')

  if $role {
    $bootstrap_role_args = {
      'extension_request' => ["pp_role=${role}"],
    }
  } else {
    $bootstrap_role_args = {}
  }

  run_task('pe_bootstrap', $name, 'Bootstrap the Puppet agent', {
    certname => $name,
    server   => $puppet_server,
  } + $bootstrap_role_args)
}
