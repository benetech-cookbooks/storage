require 'mixlib/shellout'

module StorageCookbook
  module Zfs
    RAID0 = ''
    RAID1 = ' mirror'
    FS_TYPE = 'zfs'
    FS_OPTS = { 'root' => %w(devices=off setuid=off exec=off),
                'tmp' => %w(devices=off setuid=off exec=off),
                'home' => %w(devices=off setuid=off),
                'var' => %w(devices=on setuid=off) }

    def self.create_volume(volume_name, raid_level, devices, options = {})
      if ! File.exist? '/sbin/zpool'
        puts "tried to run create_volume without ZoL installed!? (hopefully chef compile phase)"
      else
        puts "entering create_volume"
        dev_list_string = StorageCookbook::Utils.dev_string_from_array(devices)

        opts_string = ''
        opts_string = opts_string + " -m #{options[:mount_point]}" unless options[:mount_point].nil?

        zpool_list = Mixlib::ShellOut.new('zpool list')
        zpool_list.run_command
        zpool_array = zpool_list.stdout.lines.to_a.drop(1).map { |zpool| zpool.split(' ')[0]}
        if ! zpool_array.include? volume_name
          puts "creating zpool: " + "zpool create -f#{opts_string} #{volume_name}#{raid_level} #{dev_list_string}"
          create_pool_cmd = Mixlib::ShellOut.new("zpool create -f#{opts_string} #{volume_name} #{raid_level} #{dev_list_string}")
          create_pool_cmd.run_command
          if ! create_pool_cmd.status
            raise "failed creating zpool #{volume_name}"
          end
        end
      end
    end

    def self.create_subvolume(volume_name, subvolume_name, options = {})
      if ! File.exist? '/sbin/zfs'
        puts "tried to run create_subvolume without ZoL installed!? (hopefully chef compile phase)"
      else
        opts_string = ''
        opts_string = opts_string + " -o mountpoint=#{options[:mount_point]}" unless options[:mount_point].nil?

        zfs_list_cmd = Mixlib::ShellOut.new('zfs list')
        zfs_list_cmd.run_command
        zfs_array = zfs_list_cmd.stdout.lines.to_a.drop(1).map { |zfs| zfs.split(' ')[0]}
        if ! zfs_array.include? "#{volume_name}/#{subvolume_name}"
          cmd_string = "zfs create#{opts_string} #{volume_name}/#{subvolume_name}"
          puts "creating subvolume: " + cmd_string
          zfs_create_cmd = Mixlib::ShellOut.new(cmd_string)
          zfs_create_cmd.run_command
          raise "failed creating zfs subvolume #{volume_name}/#{subvolume_name}" unless zfs_create_cmd.status
        end
      end
    end

    def populate(root_vol_name, filesystems)
      root_dir = "/#{root_vol_name}"

      # unmount the default storage from vanilla ubuntu ami
      mount "/mnt" do
        device "/dev/xvdb"
        action [:umount, :disable]
      end

      directory root_dir do
        action :create
      end

      StorageCookbook::Zfs.create_volume(root_vol_name, raid_level, devices)

      filesystems.each do |subvol, opts|
        next if subvol.eql? "root"

        tmpdir = "/#{subvol}.tmp"

        ruby_block "create_subvol_#{subvol}" do
          block do
            # create the subvol
            StorageCookbook::Zfs.create_subvolume(root_vol_name, subvol, mount_point: tmpdir)
          end
          not_if "zfs list | grep -q #{root_vol_name}/#{subvol}"
          notifies :run, "execute[clone_contents_#{subvol}]", :delayed
        end

        # copy content is step #2
        execute "clone_contents_#{subvol}" do
          command "rsync -qav /#{subvol}/ #{tmpdir}/"
          action :nothing
          notifies :run, "execute[reset_mountpoint_#{subvol}]", :delayed
        end

        # remount at real mountpoint is step #3
        execute "reset_mountpoint_#{subvol}" do
          command "mv /#{subvol} /#{subvol}.off && zfs set mountpoint=/#{subvol} #{root_vol_name}/#{subvol}"
          action :nothing
          notifies :delete, "directory[tmp_#{tmpdir}]", :delayed
        end

        # remove the tmpdir is step #6
        directory "tmp_#{tmpdir}" do
          path tmpdir
          recursive true
          action :nothing
          notifies :create, "ruby_block[set_opts_#{subvol}]", :delayed
        end

        ruby_block "set_opts_#{subvol}" do
          block do
            StorageCookbook::Zfs::FS_OPTS[subvol].each do |option|
              zfs_set_cmd = Mixlib::ShellOut.new("zfs set #{option} #{root_vol_name}/#{subvol}")
              zfs_set_cmd.run_command
            end
          end
          only_if "zfs list | grep #{root_vol_name}/#{subvol}"
        end

        directory "subvol_root_#{subvol}" do
          path "/#{subvol}"
          owner "root"
          group "root"
          mode filesystems[subvol][0]
          only_if { Dir.exist? "/#{subvol}"}
        end
      end
    end
  end
end