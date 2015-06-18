class Chef
  class Resource
    class Zpool < Chef::Resource::LWRPBase
      self.resource_name = :zfs_ephemeral_storage
      actions :create
      default_action :create

      attribute :raid_level ,kind_of: String, required: false, default: ''
      attribute :name, name_attribute: true, kind_of: String, required: true, default: nil
      attribute :devices, kind_of: [Array, String], required: true, default: nil
      attribute :mount_point, kind_of: String, required: false, default: nil
    end
  end
end