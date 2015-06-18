require 'mixlib/shellout'

module StorageCookbook
  module Zfs
    RAID0 = ''
    RAID1 = ' mirror'
    BASE_FS = { :root => { :perms => 00755, :opts => %w(devices=off setuid=off exec=off) },
                :tmp => { :perms => 01777, :opts => %w(devices=off setuid=off exec=off) },
                :home => { :perms => 00755, :opts => %w(devices=off setuid=off) },
                :var => { :perms => 00755, :opts => %w(devices=on setuid=off) }

    def create_zpool(zpool_name, raid_level, devices, options = {})
      devices_string = StorageCookbook::Utils.dev_string_from_array(devices)

      opts_string = ''
      opts_string = opts_string + " -m #{options[:mount_point]}" unless options[:mount_point].nil?

      cmd = Mixlib::ShellOut.new("zpool create -f#{opts_string} #{zpool_name} #{raid_level} #{devices_string}")
      cmd.run_command.error!
    end

    def create_zfs(zpool_name, zfs_name, options = {})
      opts_string = ''
      opts_string = opts_string + " -o mountpoint=#{options[:mount_point]}" unless options[:mount_point].nil?

      cmd = Mixlib::ShellOut.new("zfs create#{opts_string} #{zpool_name}/#{zfs_name}")
      cmd.run_command.error!
    end
  end
end


