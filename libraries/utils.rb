require 'ostruct'

module StorageCookbook
  module Utils
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
  end
end