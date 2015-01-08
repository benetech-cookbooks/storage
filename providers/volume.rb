def initialize(*args)
  super
  @action = :create
end

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create
    end
  end
end

def create
  dev_list_string = xvdevs.map { |dev| " #{dev}" }*''
  case new_resource.fs_type
    when "btrfs"
      package "btrfs-tools" do
        action :upgrade
      end
      if (!File.exists? "/dev/disk/by-label/#{new_resource.volume_label}")
        execute "mkfs.btrfs -f -L #{new_resource.volume_label} -d #{new_resource.raid_type}#{dev_list_string}"
      end
    when "zfs"
      include_recipe "zfs_linux::default"
      execute "zpool -f create #{new_resource.volume_label} #{new_resource.raid_type}#{dev_list_string}" do
        not_if `zpool list | grep #{new_resource.volume_label}`
      end
    else
      raise "Invalid filesystem format requested: #{new_resource.fs_type}"
  end
end