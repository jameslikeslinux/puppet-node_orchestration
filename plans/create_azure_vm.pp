# Create an Azure VM with default settings
#
# @param name The name of the instance to create
plan node_orchestration::create_azure_vm (
  String $name,
  Enum['small', 'medium', 'large'] $size,
  Optional[String] $image_id = undef,
  Optional[String] $admin_user = undef,
  Optional[String] $key_name = undef,
  Optional[String] $resource_group = undef,
) {
  # Let defaults be defined in Hiera, overridden with parameters
  $real_image_id       = pick($image_id, lookup('node_orchestration::az_image_id', Optional[String], 'first', undef))
  $real_admin_user     = pick($admin_user, lookup('node_orchestration::az_admin_user', Optional[String], 'first', undef))
  $real_key_name       = pick($key_name, lookup('node_orchestration::az_key_name', Optional[String], 'first', undef))
  $real_resource_group = pick($resource_group, lookup('node_orchestration::az_resource_group', Optional[String], 'first', undef))

  $task_server     = lookup('node_orchestration::task_server', String)
  $vm_sizes        = lookup('node_orchestration::az_vm_sizes', Hash)

  unless $vm_sizes[$size] {
    fail("Size '${size}' not found in 'node_orchestration::az_vm_sizes' lookup hash")
  }

  $vm_create_command = [
    '/usr/bin/az', 'vm', 'create',
    '-n', $name,
    '-g', $real_resource_group,
    '--image', $real_image_id,
    '--size', $vm_sizes[$size],
    '--admin-username', $real_admin_user,
    '--ssh-key-name', $real_key_name,
  ].shellquote

  $vm_info = run_command($vm_create_command, $task_server, 'Create the VM').first.value['stdout'].parsejson

  log::info('Waiting for instance to finish booting')
  ctrl::sleep(60)

  run_plan('node_orchestration::bootstrap_agent', {
    name     => $name,
    user     => $real_admin_user,
    hostname => $vm_info['publicIpAddress'],
  })
}
