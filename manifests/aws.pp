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
  ensure_resource('package', ['aws-sdk', 'retries'], {
    ensure   => installed,
    provider => 'puppet_gem',
  })

  # Manage root user's AWS credentials, especially as used by Bolt 'apply' code
  file {
    default:
      owner => 'root',
      group => 'root',
    ;

    '/root/.aws':
      ensure => directory,
      mode   => '0755',
    ;

    '/root/.aws/credentials':
      ensure => file,
      mode   => '0400',
    ;
  }
  -> ini_setting {
    default:
      ensure  => present,
      path    => '/root/.aws/credentials',
      section => 'default',
    ;

    'root-aws-credentials-aws_access_key_id':
      setting => 'aws_access_key_id',
      value   => $access_key_id,
    ;

    'root-aws-credentials-aws_secret_access_key':
      setting => 'aws_secret_access_key',
      value   => $secret_access_key,
    ;
  }

  # Manage Puppet agent's AWS credentials
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
