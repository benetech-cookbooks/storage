class ZfsEphemeralStorage < EphemeralStorage
  # make naming correspond between different impls
  @@raid1 = :mirror

  @@fs_opts = { root => '-o devices=off -o setuid=off -o exec=off',
                tmp => '-o devices=off -o setuid=off -o exec=off',
                home => '-o devices=off -o setuid=off',
                var => '-o devices=off -o setuid=off' }

  @@root_dir = "/ephemeral-zfs"

  def initialize(raid_type)
    super
  end

  def self.raid1
    @@raid1
  end
end