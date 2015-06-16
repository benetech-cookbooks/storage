require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'btrfs'

class Chef
  class Provider
    class BtrfsEphemeralStorage < Chef::Provider::LWRPBase
      include StorageCookbook::EphemeralStorage
      include StorageCookbook::Btrfs

      use_inline_resources if defined?(use_inline_resources)

      action :create do
        @filesystems = StorageCookbook::EphemeralStorage::FS_PERMS
        @fstype = StorageCookbook::Btrfs::FS_TYPE
        @raid_level = new_resource.raid_level
        @vol_name = "ephemeral-#{fstype}"
        @root_dir = "/#{@vol_name}"

        @devices = self.find_ephemeral_devices

        # combine arrays to fill iqn fs options
        StorageCookbook::Btrfs::FS_OPTS.each { |key, opts| @filesystems[key].push(opts) }

        self.populate(@vol_name, @filesystems)
      end

      def whyrun_supported?
        true
      end

      def filesystems
        @filesystems
      end

      def devices
        @devices
      end

      def fstype
        @fstype
      end

      def raid_level
        @raid_level
      end

      def root_vol_name
        @vol_name
      end

      def root_dir
        @root_dir
      end
    end
  end
end