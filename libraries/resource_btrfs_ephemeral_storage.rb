class Chef
  class Resource
    class BtrfsEphemeralStorage < Chef::Resource::LWRPBase
      self.resource_name = :btrfs_ephemeral_storage
      actions :create
      default_action :create

      attribute :raid_level, name_attribute: true ,kind_of: String, required: true, default: nil
    end
  end
end