root_zpool = node['storage']['root_zpool_name']

# we purge lxd and lxcfs packages because they are unneccessary (we use docker) and lxcfs makes special files in /var
# that will block

disks_to_use = []

zpool root_zpool do
  disks lazy { node[:aws][:ephemeral_volume].map { |k,v| v['device'] if k =~ /#{root_zpool}/ }}
end

zfs root_zpool + '/docker' do
  mountpoint '/var/lib/docker'
end