require 'ostruct'

module StorageCookbook
  module EphemeralStorage
    FS_PERMS = {'root' => [00755],
                'tmp'  => [01777],
                'home' => [00755],
                'var'  => [00755]}

    def find_ephemeral_devices
      metadata_host = '169.254.169.254'
      block_dev_map_path = '/latest/meta-data/block-device-mapping/'
      dev_size_cmd = "blockdev --getsize64"
      dev_list = []
      aws_dev_list = Net::HTTP.get_response(metadata_host, block_dev_map_path)

      # Create an array of Dev objects
      aws_dev_list.body.split("\n").each do |aws_dev|
        next if [ "root", "ami" ].include? aws_dev
        new_dev = OpenStruct.new
        new_dev.aws_name = aws_dev
        new_dev.dev_name = Net::HTTP.get_response(metadata_host, "#{block_dev_map_path}/#{aws_dev}").body
        new_dev.fixed_dev_name = "xv#{new_dev.dev_name.dup[1..-1]}"
        new_dev.size_bytes = `#{dev_size_cmd} /dev/#{new_dev.fixed_dev_name}`
        dev_list.push(new_dev)
      end

      dev_list
    end
  end
end
