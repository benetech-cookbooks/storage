require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'zfs'

class Chef
  class Provider
    class ZfsStorage < Chef::Provider::LWRPBase
      include StorageCookbook::Zfs

      use_inline_resources if defined?(use_inline_resources)

      action :create do
        @fstype = StorageCookbook::Zfs::FS_TYPE
        @raid_level = @new_resource.raid_level
        @vol_name = @new_resource.vol_name
        @devices = @new_resource.devices
        @mount_point = @new_resource.mount_point

        # unmount the default storage from vanilla ubuntu ami
        mount "/mnt" do
          device "/dev/xvdb"
          action [:umount, :disable]
          ignore_failure true
        end

        # default mountpoint if one isnt set
        if @mount_point.nil?
          @mount_point = "/#{@vol_name}"
        end

        directory @mount_point do
          action :create
        end

        ruby_block "create_volume_#{vol_name}" do
          block do
            StorageCookbook::Zfs.create_volume(@vol_name, @raid_level, @devices, { :mount_point => @mount_point })
            not_if "zpool list | grep -q #{@vol_name}"
          end
        end

      end

      def whyrun_supported?
        true
      end

      def fstype
        @fstype
      end

      def raid_level
        @raid_level
      end

      def devices
        @devices
      end

      def mount_point
        @mount_point
      end
    end
  end
end