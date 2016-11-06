root_zpool = node['storage']['root_zpool_name']

# we purge lxd and lxcfs packages because they are unneccessary (we use docker) and lxcfs makes special files in /var
# that will block

package 'lxd' do
  action :purge
end

package 'lxcfs' do
  action :purge
end

zpool root_zpool do
  disks lazy { node[:aws][:ebs_volume].map { |k,v| v['device'] if k =~ /#{root_zpool}/ } }
end

node['storage']['root_filesystems'].keys.each do |fs|

  # move the existing data out of the way
  execute "mv_/#{fs}_to_/#{fs}.off" do
    command "mv /#{fs} /#{fs}.off"
    not_if { node['storage']['root_filesystems'][fs]['rsync_completed'] }
    notifies :create, "directory[recreate_mountpoint_#{fs}]", :immediately
  end

  # recreate the mountpoint
  directory "recreate_mountpoint_#{fs}" do
    path "/#{fs}"
    mode lazy { node['storage']['root_filesystems'][fs]['mode'] }
    action :nothing
    notifies :create, "zfs[#{root_zpool}/#{fs}]", :immediately
  end

  zfs "#{root_zpool}/#{fs}" do
    mountpoint "/#{fs}"
    action :nothing
    notifies :run, "execute[rsync_#{fs}]", :immediately
  end

  execute "rsync_#{fs}" do
    command "rsync --ignore-missing-args -avxHAXS /#{fs}.off/* /#{fs}/"
    action :nothing
    notifies :run, "ruby_block[set_rsync_completed_attribute_#{fs}]", :immediately
    returns [0, 23]
  end

  ruby_block "set_rsync_completed_attribute_#{fs}" do
    block do
      node.normal['storage']['root_filesystems'][fs]['rsync_completed'] = true
    end
    action :nothing
    notifies :delete, "directory[delete_/#{fs}.off]", :immediately
  end

  directory "delete_/#{fs}.off" do
    path "/#{fs}.off"
    recursive true
    action :nothing
    only_if { node['storage']['root_filesystems'][fs]['rsync_completed'] }
  end

  # set any zfs flags not already set
  node['storage']['root_filesystems'][fs]['opts'].each {|key, value|
    execute "zfs set #{key}=#{value} #{root_zpool}/#{fs}" do
      only_if "[[ $(zfs get #{key} #{root_zpool}/#{fs} | tr -s ' ' | tail -n1 | cut -d' ' -f3) != #{value} ]]"
    end
  }
end