# Register a new node in the PE inventory and run pe_bootstrap against it
#
# @param name The desired node certname
# @param user The SSH user to bootstrap with
# @param hostname The real hostname or IP address of the node to bootstrap
plan node_orchestration::bootstrap_agent (
  String $name,
  String $user,
  Stdlib::Host $hostname,
) {
  $task_server     = lookup('node_orchestration::task_server', String)
  $puppet_server   = lookup('node_orchestration::puppet_server', String, 'first', $task_server)
  $api_token       = lookup('node_orchestration::api_token', String)
  $ssh_private_key = lookup('node_orchestration::ssh_private_key', String)

  $type_header = 'Content-Type: application/json'
  $auth_header = "X-Authentication: ${api_token}"
  $uri = 'https://localhost:8143/inventory/v1/command/create-connection'

  $connection_config = {
    'certnames'            => [$name],
    'type'                 => 'ssh',
    'parameters'           => {
      'user'     => $user,
      'run-as'   => 'root',
      'hostname' => $hostname,
    },
    'sensitive_parameters' => {
      'private-key-content' => $ssh_private_key,
    },
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

  run_task('pe_bootstrap', $name, 'Bootstrap the Puppet agent', {
    certname => $name,
    server   => $puppet_server,
  })
}
