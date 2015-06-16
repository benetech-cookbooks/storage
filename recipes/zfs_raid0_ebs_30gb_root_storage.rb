include_recipe 'zfs_linux::default'

zfs_ebs_storage 'root-zfs' do
  raid_type StorageCookbook::Zfs::RAID0
  ebs_vol_count 1
  ebs_vol_size 30
  is_root_vol true
end
