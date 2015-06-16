require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'zfs'

class Chef
  class Provider
    class ZfsEbsStorage < Chef::Provider::LWRPBase
      include StorageCookbook::Zfs

      use_inline_resources if defined?(use_inline_resources)

      action :create do
        @fstype = StorageCookbook::Zfs::FS_TYPE
        @raid_level = @new_resource.raid_level
        @vol_name = @new_resource.vol_name
        @mount_point = @new_resource.mount_point
        @ebs_vol_count = @new_resource.ebs_vol_count
        @ebs_vol_size = @new_resource.ebs_vol_size
        @ebs_vol_type = @new_resource.ebs_vol_type
        @is_root_vol = @new_resource.is_root_vol

        # access our aws credentials
        aws = data_bag_item("aws", "main")

        # proceed with creating/attaching the ebs volumes
        avail_devs = StorageCookbook::Utils.avail_devs
        dev_list = []
        i = 0
        while i < @ebs_vol_count
          dev = avail_devs.pop
          aws_ebs_volume "#{@vol_name}#{i}" do
            aws_access_key aws['aws_access_key_id']
            aws_secret_access_key aws['aws_secret_access_key']
            size @ebs_vol_size
            volume_type @ebs_vol_type
            device dev
            snapshot_id NIL
            action [ :create, :attach ]
          end
          dev_list.push(dev)
          i += 1
        end

        zfs_storage @vol_name do
          raid_level @raid_level
          devices dev_list
          mount_point @mount_point
        end

        if @is_root_vol
          self.populate(@vol_name, StorageCookbook::EphemeralStorage::FS_PERMS)
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

      def number_ebs_vols
        @ebs_vol_count
      end

      def size_ebs_vols
        @ebs_vol_size
      end

      def is_root_vol
        @is_root_vol
      end
    end
  end
end