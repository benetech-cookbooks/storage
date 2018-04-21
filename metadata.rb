name             'storage'
maintainer       'Ron Ellis'
maintainer_email 'rone@benetech.org'
license          'All rights reserved'
description      'Installs/Configures storage'
long_description 'Installs/Configures storage'
version          '0.7.0'

depends 'zfs_linux', '~> 2.1.3'
depends 'aws', '~> 7.3.1'
depends 'chef_zpool', '~> 0.1.0'
depends 'chef_zfs', '~> 1.0.2'
