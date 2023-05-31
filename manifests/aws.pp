# Configure pre-requisites for puppetlabs-aws module
#
# @param access_key_id IAM access key with EC2 privileges
# @param secret_access_key IAM secret access key associated with the access key ID
# @param region The default AWS region to interact with
#
# @see https://forge.puppet.com/modules/puppetlabs/aws
class node_orchestration::aws (
  String $access_key_id,
  Sensitive $secret_access_key,
  String $region,
) {
  package { [
    'aws-sdk',
    'retries',
  ]:
    ensure   => installed,
    provider => 'puppet_gem',
  }

  file { "${settings::confdir}/puppetlabs_aws_credentials.ini":
    ensure => file,
    mode   => '0400',
    owner  => $settings::user,
    group  => $settings::group,
  }
  -> ini_setting {
    default:
      ensure  => present,
      path    => "${settings::confdir}/puppetlabs_aws_credentials.ini",
      section => 'default',
    ;

    'puppetlabs_aws_credentials-aws_access_key_id':
      setting => 'aws_access_key_id',
      value   => $access_key_id,
    ;

    'puppetlabs_aws_credentials-aws_secret_access_key':
      setting => 'aws_secret_access_key',
      value   => $secret_access_key,
    ;
  }

  ini_setting { 'puppetlabs_aws_configuration-region':
    ensure  => present,
    path    => "${settings::confdir}/puppetlabs_aws_configuration.ini",
    section => 'default',
    setting => 'region',
    value   => $region,
  }
}
