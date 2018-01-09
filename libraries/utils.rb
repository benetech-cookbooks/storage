require 'ostruct'

module StorageCookbook
  module Utils

    def self.get_nvme_dev(dev)
      # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html
      (0..26).each do |n|
        nvme_dev = "/dev/nvme#{n}n1"
        next unless system("nvme id-ctrl -v #{nvme_dev} | grep -q #{dev}")
        return nvme_dev
      end
    end

    def self.next_avail_dev
      # /dev/sd[f-p] is amazons recommended
      # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-attaching-volume.html#device_naming
      device_letters = *('f'..'p')
      dev_base = '/dev/xvd'
      next_avail_dev = ""

      device_letters.each do |l|
        cur_dev = "#{dev_base}#{l}"
        next unless (!system("file #{cur_dev}"))
        next_avail_dev = "#{cur_dev}"
        break
      end

      raise "next available dev returned an empty reply" if next_avail_dev.empty?

      return next_avail_dev
    end

    def self.avail_devs
      # /dev/sd[f-p] is amazons recommended
      # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-attaching-volume.html#device_naming
      device_letters = *('f'..'p')
      dev_base = '/dev/xvd'
      avail_devs = []

      device_letters.each do |l|
        cur_dev = dev_base + l
        next if File.exist? cur_dev
        avail_devs.push(cur_dev)
      end

      raise "no available device letters found!" if avail_devs.empty?

      return avail_devs
    end

    def self.dev_string_from_array(devices)
      if devices.first.instance_of? OpenStruct
        return devices.map { |dev| "/dev/#{dev.fixed_dev_name}" }*' '
      elsif devices.first.instance_of? String
        return devices.map { |dev| dev }*' '
      else
        raise "invalid type passed in #{devices.first.class}"
      end
    end

    def self.find_ephemeral_devices
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
    end
  end
end