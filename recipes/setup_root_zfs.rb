root_zpool = node['storage']['root_zpool_name']

zpool root_zpool do
  disks lazy { ZTools.rpool_devs(node['storage']['root_zpool_name'],
                                 node['aws']['ebs_volume']) }
end

node['storage']['root_filesystems'].keys.each do |fs|
  rsync_complete_path = "/#{fs}/.rsync_completed"

  execute "mv_/#{fs}_to_/#{fs}.off" do
    command "mv /#{fs} /#{fs}.off"
    not_if { ( Dir.exist?("/#{fs}.off") || File.exist?(rsync_complete_path) ) }
  end

  directory "recreate_mountpoint_#{fs}" do
    path "/#{fs}"
    mode lazy { node['storage']['root_filesystems'][fs]['mode'] }
  end

  zfs "#{root_zpool}/#{fs}" do
    mountpoint "/#{fs}"
  end

  node['storage']['root_filesystems'][fs]['opts'].each {|key, value|
    execute "zfs set #{key}=#{value} #{root_zpool}/#{fs}" do
      only_if "[[ $(zfs get #{key} #{root_zpool}/#{fs} | tr -s ' ' | tail -n1 | cut -d' ' -f3) != #{value} ]]"
    end
  }

  execute "rsync_#{fs}" do
    command "rsync --ignore-missing-args -a /#{fs}.off/* /#{fs}/"
    not_if { File.exist? rsync_complete_path }
  end

  file rsync_complete_path do
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  directory "/#{fs}.off" do
    recursive true
    action :delete
    only_if { File.exist? rsync_complete_path }
  end
end

class ZTools
  def self.rpool_devs(pool_name, ebs_volumes)
    result = []
    root_pool = pool_name
    pool_ebs_vols = ebs_volumes.select {|k,v| k.to_s =~ /#{root_pool}/ }
    pool_devs = pool_ebs_vols.collect {|k,v| v['device']}
    result + pool_devs
  end
end