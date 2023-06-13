# Configure pre-requisites for puppetlabs-azure module
#
# @param tenant_id The Azure AD tenant ID containing your app registration
# @param client_id The ID associated with your app registration
# @param client_secret The password assigned to your app registration
#
# @see https://forge.puppet.com/modules/puppetlabs/azure
class node_orchestration::azure (
  String $tenant_id,
  String $client_id,
  Sensitive $client_secret,
) {
  case $facts['os']['family'] {
    'Debian': {
      exec { 'install-azure-cli':
        command => '/usr/bin/curl -sL https://aka.ms/InstallAzureCLIDeb | /bin/bash',
        creates => '/usr/bin/az',
        before  => Exec['azure-cli-login'],
      }
    }

    default: {
      notice("Azure CLI installation not handled for ${facts['os']['family']}")
    }
  }

  exec { 'azure-cli-login':
    command => Sensitive("/usr/bin/az login --service-principal -u ${client_id} -p ${client_secret.unwrap} --tenant ${tenant_id}"),
    unless  => '/usr/bin/az account show',
  }
}
