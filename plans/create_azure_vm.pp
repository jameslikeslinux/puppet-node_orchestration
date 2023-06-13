# Create an Azure VM with default settings
#
# @param name The name of the VM to create
# @param size The type of VM to create (small, medium, large)
# @param image_id Overrides the default image ID set in Hiera
# @param admin_user Overrides the initial VM username set in Hiera
# @param admin_password Overrides the initial VM password set in Hiera
# @param resource_group Overrides the resource group set in Hiera
# @param os_disk_size If set, the size of the OS disk in GB. Otherwise, use Azure defaults.
# @param data_disk_sizes The sizes of the data disks to attach in GB
plan node_orchestration::create_azure_vm (
  String $name,
  Enum['small', 'medium', 'large'] $size,
  Optional[String] $image_id = undef,
  Optional[String] $admin_user = undef,
  Optional[Sensitive] $admin_password = undef,
  Optional[String] $resource_group = undef,
  Optional[Integer] $os_disk_size = undef,
  Array[Integer] $data_disk_sizes = [],
) {
  # Let defaults be defined in Hiera, overridden with parameters
  $real_image_id       = pick($image_id, lookup('node_orchestration::az_image_id', Optional[String], 'first', undef))
  $real_admin_user     = pick($admin_user, lookup('node_orchestration::az_admin_user', Optional[String], 'first', undef))
  $real_admin_password = pick($admin_password, lookup('node_orchestration::az_admin_password', Optional[Sensitive], 'first', undef))
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

    # Avoid SSH pubkey b/c Azure only supports ssh-rsa, for which
    # PE wants to use SHA1 hashes disallowed by modern OpenSSH
    '--admin-username', $real_admin_user,
    '--admin-password', $real_admin_password.unwrap,
    '--authentication-type', 'password',

    $os_disk_size ? {
      undef   => [],
      default => ['--os-disk-size', String($os_disk_size)],
    },

    $data_disk_sizes ? {
      []      => [],
      default => ['--data-disk-sizes-gb', $data_disk_sizes.map |$s| { String($s) }],
    },
  ].flatten.shellquote

  $vm_info = run_command($vm_create_command, $task_server, 'Create the VM').first.value['stdout'].parsejson

  log::info('Waiting for instance to finish booting')
  ctrl::sleep(20)

  run_plan('node_orchestration::bootstrap_agent', {
    name     => $name,
    hostname => $vm_info['publicIpAddress'],
    user     => $real_admin_user,
    password => $real_admin_password,
  })
}
