# Debian/nexenta specific build module
#
# build::install { 'top':
#   download => 'http://www.unixtop.org/dist/top-3.7.tar.gz',
#   creates  => '/usr/local/bin/top',
# }
define build::install ($download, $creates, $configure=true, $pkg_folder='', $pkg_format="tar", $pkg_extension="", $buildoptions="", $extractorcmd="", $rm_build_folder=true) {
  
  $cwd    = "/usr/local/src"
  $test   = "/usr/bin/test"
  $unzip  = "/usr/bin/unzip"
  $tar    = "/bin/tar"
  $bunzip = "/usr/bin/bunzip2"
  $gunzip = "/usr/bin/gunzip"
  
  $filename = basename($download)
  
  $extension = $pkg_format ? {
    zip     => ".zip",
    bzip    => ".tar.bz2",
    tar     => ".tgz",
    default => $pkg_extension,
  }
  
  $foldername = $pkg_folder ? {
    ''      => gsub($filename, $extension, ""),
    default => $pkg_folder,
  }
  
  $extractor = $pkg_format ? {
    zip     => "$unzip -q -d $cwd $cwd/$filename",
    bzip    => "$bunzip -c $cwd/$filename | $tar -xf -",
    tar     => "$gunzip < $cwd/$filename | $tar -xf -",
    default => $extractorcmd,
  }

  Exec {
    unless => "$test -f $creates",
  }
  
  exec { "download_$name":
    cwd     => "$cwd",
    command => "/usr/bin/wget -q $download",
    timeout => 120, # 2 minutes
  }
  
  exec { "extract_$name":
    cwd     => "$cwd",
    command => "$extractor",
    timeout => 120, # 2 minutes
    require => Exec["download_$name"],
  }
  
  exec { "config_$name":
    cwd     => "$cwd/$foldername",
    command => "$cwd/$foldername/configure $buildoptions",
    timeout => 120, # 2 minutes
    require => Exec["extract_$name"],
    onlyif => $configure,
  }
  
  exec { "make_install_$name":
    cwd     => "$cwd/$foldername",
    command => "/usr/bin/make && /usr/bin/make install",
    timeout => 600, # 10 minutes
    require => $configure ? {
       false => Exec["extract_$name"],
       default => Exec["config_$name"]
    },
  }
  
  # remove build folder
  case $rm_build_folder {
    true: {
      notice("remove build folder")
      exec { "remove_$name_build_folder":
        cwd     => "$cwd",
        command => "/usr/bin/rm -rf $cwd/$foldername",
        require => Exec["make_install_$name"],
      } # exec
    } # true
  } # case
  
}

define build::requires ( $ensure='installed', $package ) {
  if defined( Package[$package] ) {
    debug("$package already installed")
  } else {
    package { $package: ensure => $ensure }
  }
}
