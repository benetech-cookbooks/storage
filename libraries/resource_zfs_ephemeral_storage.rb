class Chef
  class Resource
    class ZfsEphemeralStorage < Chef::Resource::LWRPBase
      self.resource_name = :zfs_ephemeral_storage
      actions :create
      default_action :create

      attribute :raid_level, name_attribute: true ,kind_of: String, required: true, default: nil
    end
  end
end