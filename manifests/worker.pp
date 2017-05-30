class fstep::worker (
  $component_name           = 'fs-tep-worker',

  $install_path             = '/var/fs-tep/worker',
  $config_file              = '/var/fs-tep/worker/fs-tep-worker.conf',
  $logging_config_file      = '/var/fs-tep/worker/log4j2.xml',
  $properties_file          = '/var/fs-tep/worker/application.properties',

  $service_enable           = true,
  $service_ensure           = 'running',

  # fs-tep-worker application.properties config
  $application_port         = undef,
  $grpc_port                = undef,

  $serviceregistry_user     = undef,
  $serviceregistry_pass     = undef,
  $serviceregistry_host     = undef,
  $serviceregistry_port     = undef,
  $serviceregistry_url      = undef,

  $worker_environment       = 'LOCAL',

  $cache_concurrency        = 4,
  $cache_maxweight          = 1024,
  $cache_dir                = 'dl',
  $jobs_dir                 = 'jobs',

  $ipt_auth_endpoint        = 'https://finder.eocloud.eu/resto/api/authidentity',
  # These are not undef so they're not mandatory parameters, but must be set correctly if IPT downloads are required
  $ipt_auth_domain          = '__secret__',
  $ipt_download_base_url    = '__secret__',

  $custom_config_properties = { },
) {

  require ::fstep::globals

  contain ::fstep::common::datadir
  contain ::fstep::common::java
  # User and group are set up by the RPM if not included here
  contain ::fstep::common::user
  contain ::fstep::common::docker

  $real_application_port = pick($application_port, $fstep::globals::worker_application_port)
  $real_grpc_port = pick($grpc_port, $fstep::globals::worker_grpc_port)

  $real_serviceregistry_user = pick($serviceregistry_user, $fstep::globals::serviceregistry_user)
  $real_serviceregistry_pass = pick($serviceregistry_pass, $fstep::globals::serviceregistry_pass)
  $real_serviceregistry_host = pick($serviceregistry_host, $fstep::globals::server_hostname)
  $real_serviceregistry_port = pick($serviceregistry_port, $fstep::globals::serviceregistry_application_port)
  $serviceregistry_creds = "${real_serviceregistry_user}:${real_serviceregistry_pass}"
  $serviceregistry_server = "${real_serviceregistry_host}:${real_serviceregistry_port}"
  $real_serviceregistry_url = pick($serviceregistry_url,
    "http://${serviceregistry_creds}@${serviceregistry_server}/eureka/")

  ensure_packages(['fs-tep-worker'], {
    ensure => 'latest',
    name   => 'fs-tep-worker',
    tag    => 'fstep',
    notify => Service['fs-tep-worker'],
  })

  file { ["${fstep::common::datadir::data_basedir}/${cache_dir}", "${fstep::common::datadir::data_basedir}/${jobs_dir}"]:
    ensure  => directory,
    owner   => $fstep::globals::user,
    group   => $fstep::globals::group,
    mode    => '755',
    recurse => false,
    require => File[$fstep::common::datadir::data_basedir],
  }

  file { $config_file:
    ensure  => 'present',
    owner   => $fstep::globals::user,
    group   => $fstep::globals::group,
    content =>
      'JAVA_OPTS="-DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Djava.util.logging.manager=org.apache.logging.log4j.jul.LogManager"'
    ,
    require => Package['fs-tep-worker'],
    notify  => Service['fs-tep-worker'],
  }

  ::fstep::logging::log4j2 { $logging_config_file:
    fstep_component => $component_name,
    require        => Package['fs-tep-worker'],
    notify         => Service['fs-tep-worker'],
  }

  file { $properties_file:
    ensure  => 'present',
    owner   => $fstep::globals::user,
    group   => $fstep::globals::group,
    content => epp('fstep/worker/application.properties.epp', {
      'logging_config_file'   => $logging_config_file,
      'server_port'           => $real_application_port,
      'grpc_port'             => $real_grpc_port,
      'serviceregistry_url'   => $real_serviceregistry_url,
      'worker_environment'    => $worker_environment,
      'cache_basedir'         => "${fstep::common::datadir::data_basedir}/${cache_dir}",
      'cache_concurrency'     => $cache_concurrency,
      'cache_maxweight'       => $cache_maxweight,
      'jobs_basedir'          => "${fstep::common::datadir::data_basedir}/${jobs_dir}",
      'ipt_auth_endpoint'     => $ipt_auth_endpoint,
      'ipt_auth_domain'       => $ipt_auth_domain,
      'ipt_download_base_url' => $ipt_download_base_url,
      'custom_properties'     => $custom_config_properties,
    }),
    require => Package['fs-tep-worker'],
    notify  => Service['fs-tep-worker'],
  }

  service { 'fs-tep-worker':
    ensure     => $service_ensure,
    enable     => $service_enable,
    hasrestart => true,
    hasstatus  => true,
    require    => [Package['fs-tep-worker'], File[$properties_file]],
  }

}