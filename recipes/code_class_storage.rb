include_recipe 'zfs_linux::default'
include_recipe 'aws'

# access our aws credentials
aws = data_bag_item("aws", "main")

avail_devs = StorageCookbook::Utils.avail_devs
dev_list = []
i = 0
while i < 2
  dev = avail_devs.pop
  aws_ebs_volume "tank#{i}" do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    size 500
    volume_type "gp2"
    device dev
    snapshot_id NIL
    action [ :create, :attach ]
  end
  puts "adding device to list: " + dev
  dev_list.push(dev)
  i = i+1
end

ruby_block "create_zfs_array" do
  block do
    StorageCookbook::Zfs.create_volume("tank", StorageCookbook::Zfs::RAID1, dev_list)
  end
  action :run
end

ruby_block "create_zfs_jenkins_subvolume" do
  block do
    StorageCookbook::Zfs.create_subvolume("tank", "jenkins")
  end
  action :run
end