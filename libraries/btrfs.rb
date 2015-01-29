module StorageCookbook
  module Btrfs
    RAID1 = 'raid1'
    FS_TYPE = 'btrfs'
    FS_OPTS = { 'tmp' => 'nosuid,nodev,noexec,subvol=tmp',
                'home' => 'nosuid,nodev,subvol=home',
                'var' => 'nosuid,nodev,subvol=var' }

    def create_volume(volume_name, raid_level, devices)
      devices_string = StorageCookbook::Utils.dev_string_from_aray(devices)

      package "btrfs-tools" do
        action :upgrade
      end

      execute "mkfs.btrfs -f -L #{volume_name} -d #{raid_level} #{devices_string}" do
        not_if { File.exist? "/dev/disk/by-label/#{volume_name}" }
      end
    end

    def create_subvolume(volume_name, subvolume_name)
      execute "btrfs subvolume create /#{volume_name}/#{subvolume_name}" do
        not_if "btrfs subvolume list /#{volume_name} | grep #{subvolume_name}"
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

      self.create_volume(root_vol_name, raid_level, devices)

      mount "/#{root_vol_name}" do
        device root_vol_name
        device_type :label
        fstype StorageCookbook::Btrfs::FS_TYPE
        options filesystems['root'][1]
        action [:enable, :mount]
      end

      filesystems.each do |subvol, opts|
        next if subvol.eql? "root"

        self.create_subvolume(root_vol_name, subvol)
        tmpdir = "/#{subvol}.tmp"

        directory tmpdir do
          action :create
          not_if "df | grep /#{subvol}"
        end

        execute "rsync -qav /#{subvol}/ #{tmpdir}/" do
          only_if { Dir.exists? tmpdir }
        end

        mount "/#{subvol}" do
          device root_vol_name
          device_type :label
          fstype StorageCookbook::Btrfs::FS_TYPE
          options filesystems[subvol][1]
          action [:enable, :mount]
        end

        execute "rsync -qav #{tmpdir}/ /#{subvol}/" do
          only_if { Dir.exists? tmpdir }
        end

        directory tmpdir do
          action :delete
          recursive true
        end

        directory "/#{subvol}" do
          owner "root"
          group "root"
          mode filesystems[subvol][0]
        end
      end
    end
  end
end