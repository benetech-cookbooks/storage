ephemeral_storage =

case new_resource.fs_type
  when "btrfs"
    ephemeral_storage = BtrfsEphemeralStorage.new(BtrfsEphemeralStorage.raid1)
  when "zfs"
    ephemeral_storage = ZfsEphemeralStorage.new(ZfsEphemeralStorage.raid1)
  else
    raise "You specified a filesystem other than btrfs or zfs, these are the only two we support. Exiting"
end

directory ephemeral_storage.root_dir do
  action :create
end

# create the primary volume
if (ephemeral_storage.dev_list.size == 2)
  volume ephemeral_storage.root_dir do
    fs_type new_resource.fs_type
    raid_type ephemeral_storage.raid1
    devices ephemeral_storage.dev_list
    mount true
  end
else
  raise "We found more than two ephemeral storage devices, cant' cope.. exiting"
end

# create all of the normal subvolumes
ephemeral_storage.filesystems each do |fs|
  subvolume fs do
    fs_type new_resource.fs_type
    parent_vol ephemeral_storage.root_dir
    mount false
  end
end

ephemeral_storage.clone_existing_content

=begin
mount ephemeral_storage.root_dir do
  device ephemeral_storage.root_dir
  device_type :label
  fstype new_resource.fs_type
  options "noexec,nodev,nosuid"
  action [:enable, :mount]
end
=end