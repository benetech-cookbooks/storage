include_recipe 'zfs_linux::default'
include_recipe 'aws'

avail_devs = StorageCookbook::Utils.avail_devs
zpool = node['storage']['root_zpool_name']
# access our aws credentials
aws = data_bag_item("aws", "main")
used_devs = []

node['storage']['root_volume_count'].times { |count|
  dev = avail_devs.pop
  used_devs.push dev
  aws_ebs_volume zpool+count.to_s do
    aws_access_key aws['aws_access_key_id']
    aws_secret_access_key aws['aws_secret_access_key']
    size node['storage']['root_volume_size']
    volume_type "gp2"
    device dev
    snapshot_id NIL
    action [ :create, :attach ]
    notifies :run, "ruby_block[set_ebs_device_attribute_#{zpool+count.to_s}]", :immediately
  end

  ruby_block "set_ebs_device_attribute_#{zpool+count.to_s}" do
    block do
      node.normal[:aws][:ebs_volume][zpool+count.to_s]['device'] = dev
    end
    action :nothing
    # notifies :run, "execute[create_gpt_partition_table_#{zpool+count.to_s}]", :immediately
    notifies :mklabel, "parted_disk[#{dev}]", :immediately
  end

  # execute "create_gpt_partition_table_#{zpool+count.to_s}" do
  #   command "/sbin/parted #{dev} mklabel gpt"
  #   retries 5
  #   retry_delay 5
  #   action :nothing
  # end

  parted_disk dev do
    label_type "gpt"
    action :nothing
    retries 5
    retry_delay 5
  end

}