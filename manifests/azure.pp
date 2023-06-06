# Configure pre-requisites for puppetlabs-azure module
#
# @param subscription_id The Azure subscription ID to operate on
# @param tenant_id The Azure AD tenant ID containing your app registration
# @param client_id The ID associated with your app registration
# @param client_secret The password assigned to your app registration
#
# @see https://forge.puppet.com/modules/puppetlabs/azure
class node_orchestration::azure (
  String $subscription_id,
  String $tenant_id,
  String $client_id,
  Sensitive $client_secret,
) {
  $gems = [
    'azure',
    'azure_mgmt_compute',
    'azure_mgmt_storage',
    'azure_mgmt_resources',
    'azure_mgmt_network',
    'hocon',
    'retries',
  ]

  ensure_resource('package', $gems, {
    ensure   => installed,
    provider => 'puppet_gem',
  })

  file { "${settings::confdir}/azure.conf":
    ensure => file,
    mode   => '0400',
    owner  => $settings::user,
    group  => $settings::group,
  }
  -> hocon_setting {
    default:
      ensure => present,
      path   => "${settings::confdir}/azure.conf",
    ;

    'azure-subscription_id':
      setting => 'azure.subscription_id',
      value   => $subscription_id,
    ;

    'azure-tenant_id':
      setting => 'azure.tenant_id',
      value   => $tenant_id,
    ;

    'azure-client_id':
      setting => 'azure.client_id',
      value   => $client_id,
    ;

    'azure-client_secret':
      setting => 'azure.client_secret',
      value   => $client_secret,
    ;
  }
}
