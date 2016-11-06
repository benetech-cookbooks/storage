#
# EBS device allocatiion and attachment
#

include_recipe 'aws'

avail_devs = StorageCookbook::Utils.avail_devs
zpool = node['storage']['root_zpool_name']
# access our aws credentials
aws = Chef::EncryptedDataBagItem.load('aws', 'main')
used_devs = []

node['storage']['root_volume_count'].times { |count|
  dev = avail_devs.pop

  aws_ebs_volume zpool+count.to_s do
    aws_access_key aws['access_key_id']
    aws_secret_access_key aws['secret_access_key']
    size node['storage']['root_volume_size']
    volume_type "gp2"
    device dev
    snapshot_id NIL
    action [ :create, :attach ]
    retries 5
    retry_delay 5
  end

  used_devs.push dev
}

#
# EBS device Chef metadata population and general preparation for use by ZFS
#

chef_gem 'aws-sdk'

ruby_block "add_ebs_volume_metadata_to_chef_and_prepare_devices_for_use" do
  block do
    require 'aws-sdk'

    client = Aws::EC2::Client.new(
        access_key_id: aws['access_key_id'],
        secret_access_key: aws['secret_access_key'],
        region: node['aws']['default_region']
    )

    # pull EBS volume metadata from aws for each of our devices
    volumes_needing_metadata = node[:aws][:ebs_volume].select {|k,v| v['device'].nil? }
    volumes_needing_metadata.each { |k,v|
      resp = client.describe_volumes({
                                         filters: [
                                             {
                                                 name: 'volume-id',
                                                 values: [
                                                     v['volume_id'],
                                                 ],
                                             }
                                         ],
                                     })

      # now we have the device ie /dev/xvdp
      cur_dev = resp.volumes[0].attachments[0].device

      # wait around for the device ie /dev/xvdp to become available
      timeout = 0
      until File.blockdev?(cur_dev) || timeout == 1000 do
        Chef::Log.debug("device #{dev} not ready - sleeping 10s")
        timeout += 10
        sleep 10
      end

      # create a chef attribute containing the EBS vol device ie /dev/xvdp
      node.normal[:aws][:ebs_volume][k]['device'] = cur_dev

      # add gpt label so ZFS will be willing to touch the device without -f
      `parted --script #{cur_dev} mklabel gpt`
    }


  end
  action :run
  only_if { node[:aws][:ebs_volume].select {|k,v| v['device'].nil? }.size > 0 }
end