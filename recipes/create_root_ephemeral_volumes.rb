#
# ephemeral storage device metadata additions
#

include_recipe 'aws'

zpool = node['storage']['root_zpool_name']
metadata_host = '169.254.169.254'
block_dev_map_path = '/latest/meta-data/block-device-mapping/'
dev_size_cmd = 'blockdev --getsize64'
dev_list = []
aws_dev_list = Net::HTTP.get_response(metadata_host, block_dev_map_path)
count = 0

# aws/ubuntu likes to mount 1/2 ephemeral drives by default
mount "/mnt" do
  device "/dev/xvdb"
  action [:umount, :disable]
  ignore_failure true
end

#
# EBS device Chef metadata population and general preparation for use by ZFS
#

ruby_block 'add_ephemeral_volume_metadata_to_chef_and_prepare_devices_for_use' do
  block do

  # Create an array of ephemeral device objects that we are allowed to use
    aws_dev_list.body.split("\n").each do |aws_dev|
      next if %w(root ami).include? aws_dev
      new_dev = {}
      # aws gives us a dev name like /dev/sd* where linux actually sees it as /dev/xvd*
      new_dev['device'] = "/dev/xv#{Net::HTTP.get_response(metadata_host, "#{block_dev_map_path}/#{aws_dev}").body.dup[1..-1]}"
      new_dev['size'] = `#{dev_size_cmd} /dev/#{new_dev['fixed_dev_name']}`
      dev_list.push(new_dev)

      node.normal[:aws][:ephemeral_volume][zpool + count.to_s] = new_dev

      # add gpt label so ZFS will be willing to touch the device without -f
      `parted --script #{new_dev['device']} mklabel gpt`

      count += 1
    end

  end
  action :run
  not_if "zpool list | tail -n +2 | grep -q #{zpool}"
end