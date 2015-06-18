include_recipe 'zfs_linux::default'
include_recipe 'aws'

zfs_ebs_storage 'root-zfs' do
  ebs_vol_count 1
  ebs_vol_size 30
  is_root_vol true
end

