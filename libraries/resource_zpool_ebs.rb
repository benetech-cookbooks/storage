class Chef
  class Resource
    class ZpoolEbs < Chef::Resource::LWRPBase
      self.resource_name = :zfs_ephemeral_storage
      actions :create
      default_action :create

      attribute :vol_name,  name_attribute: true, kind_of: String, required: true, default: nil
      attribute :raid_level, kind_of: String, required: false, default: ''
      attribute :mount_point, kind_of: String, required: false, default: nil
      attribute :ebs_vol_count, kind_of: Fixnum, required: true, default: nil
      attribute :ebs_vol_size, kind_of: Fixnum, required: true, default: nil
      attribute :ebs_vol_type, kind_of: String, required: false, default: nil
      attribute :is_root_vol, kind_of: [TrueClass, FalseClass], required: false, default: false
    end
  end
end