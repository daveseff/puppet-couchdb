class couchdb ( 
	$manage_user        = true,
	$manage_group       = true,
	$user               = $::couchdb::params::user,
	$group              = $::couchdb::params::group,
	$couchdb_src_dir	= $::couchdb::params::src_dir
) inherits ::couchdb::params{

	Class["couchdb"] -> Couchdb::Instance <| |> -> Couchdb::Db <| |>
	
	if !defined(Package['curl']) {
		package { 'curl':
			ensure => installed,
		}
	}
	
	exec { "packager-update":
		command     => "/usr/bin/${::couchdb::params::updater} update ${::couchdb::params::updater_options}",
		timeout		=> '1200'
	}
	
	Exec["packager-update"] -> Package[$::couchdb::params::packages] -> Exec["clone"]

	$::couchdb::params::packages.each |String $pkg|{
        	if !defined(Package[$pkg]) {
			package { $pkg: ensure	=> 'installed' }
		}
	}
	
	validate_bool($manage_group)
	$couchdb_group = $manage_group ? {
		true	=> $group,
		false	=> $::couchdb::params::root_group
	}
	group { $group:
		ensure  => present,
	}
	
	validate_bool($manage_user)
	$couchdb_user = $manage_user ? {
		true	=> $user,
		false	=> 'root'
	}
	user { 'couchdb':
		name		=> $couchdb_user,
		ensure      => present,
		gid			=> $couchdb_group ,
	}
	
	file { [$couchdb_src_dir,"${couchdb_src_dir}/dependencies"]:
		ensure	=> 'directory',
	}
	
	$recursive_string = str2bool($::couchdb::params::git_rep_recursive) ? {
		true	=> '--recursive',
		false	=> ''
	}
	
	exec { 'clone':
		cwd         => "${couchdb_src_dir}",
		environment => 'HOME=${::root_home}',
		command     => "/usr/bin/git clone ${recursive_string} ${git_rep}",
		timeout     => '600',
		creates		=> "${couchdb_src_dir}/build-couchdb",
	}
	
	if $recursive_string == '' {
		exec { 'submodule init':
			cwd         => "${couchdb_src_dir}/build-couchdb",
			environment => "HOME=${::root_home}",
			command     => "/usr/bin/git submodule init",
			timeout     => '300',
			require		=> Exec['clone'],
		}
		exec { 'submodule update':
			cwd         => "${couchdb_src_dir}/build-couchdb",
			environment => "HOME=${::root_home}",
			command     => "/usr/bin/git submodule update",
			timeout     => '900',
			tries		=> 3,
			try_sleep	=> 5,
			require		=> [Exec['clone'],Exec['submodule init']]
		}
	}
}
