require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'zfs'

class Chef
  class Provider
    class ZfsEphemeralStorage < Chef::Provider::LWRPBase
      include StorageCookbook::EphemeralStorage
      include StorageCookbook::Zfs

      use_inline_resources if defined?(use_inline_resources)

      action :create do
        @filesystems = StorageCookbook::EphemeralStorage::FS_PERMS
        @fstype = StorageCookbook::Zfs::FS_TYPE
        @raid_level = new_resource.raid_level
        @root_vol_name = "ephemeral-#{fstype}"
        @root_dir = "/#{@root_vol_name}"

        @devices = self.find_ephemeral_devices

        self.populate(@root_vol_name, @filesystems)
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
        @root_vol_name
      end

      def root_dir
        @root_dir
      end
    end
  end
end