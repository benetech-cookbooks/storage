class BtrfsEphemeralStorage < EphemeralStorage
  # make naming correspond between different impls
  @@raid1 = :raid1

  @@fs_opts = { root => 'nosuid,nodev,noexec',
                tmp => 'nosuid,nodev,noexec,subvol=tmp',
                home => 'nosuid,nodev,subvol=home',
                var => 'nosuid,nodev,subvol=var' }

  @@root_dir = "/ephemeral-btrfs"

  def initialize(raid_type)
    super
  end

  def self.raid1
    @@raid1
  end

  def create_vol

  end
end