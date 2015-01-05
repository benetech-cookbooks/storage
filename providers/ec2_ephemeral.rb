require 'net/http'
require 'ostruct'

def find_ephemeral_devices
  metadata_host = '169.254.169.254'
  block_dev_map_path = '/latest/meta-data/block-device-mapping/'
  dev_size_cmd = "blockdev --getsize64"
  dev_list = []
  aws_dev_list = Net::HTTP.get_response(metadata_host, block_dev_map_path)

# Create an array of Dev objects
  aws_dev_list.body.split("\n").each do |aws_dev|
    new_dev = OpenStruct.new
    new_dev.aws_name = aws_dev
    next if new_dev.aws_name.eql? "root" || "ami"
    new_dev.dev_name = Net::HTTP.get_response(metadata_host, "#{block_dev_map_path}/#{aws_dev}").body
    new_dev.fixed_dev_name = "xv#{new_dev.dev_name.dup[1..-1]}"
    new_dev.size_bytes = `#{dev_size_cmd} /dev/#{new_dev.fixed_dev_name}`
    dev_list.push(new_dev)
  end

  return dev_list
end

def destroy_default_dev
  # WTF does Amazon format/mount one random device initially?  Idiots...
  mount "/mnt" do
    device "/dev/xvdb"
    action [:umount, :disable]
  end
end

dev_list = find_ephemeral_devices
dev_list_string = dev_list.map { |dev| "/dev/#{dev.fixed_dev_name}" }*" "

if (dev_list.size == 2)
  case new_resource.fs_type
    when "btrfs"
      fs "btrfs-root" do
        fs_type "btrfs"
        raid_type "raid1"
        devices dev_list_string
        mount true
      end
    when "zfs"
      fs "zfs-root"
        fs_type "zfs"
        raid_type "mirror"
        devices dev_list_string
        mount true
      end
  end
else
  raise "Invalid filesystem format requested: #{new_resource.fs_type}"
end

rootdir="/root-btrfs"

directory rootdir do
  action :create
end

mount rootdir do
  device "root-btrfs"
  device_type :label
  fstype "btrfs"
  #options "noexec,nodev,nosuid," + dev_list.map{ |dev| "device=/dev/#{dev.fixed_dev_name}" }*","
  options "noexec,nodev,nosuid"
  action [:enable, :mount]
end

filesystems = []
Fs = OpenStruct.new
filesystems.push(Fs.new('tmp', 'nosuid,noexec,subvol=tmp', 01777))
filesystems.push(Fs.new('home', 'nosuid,subvol=home', 00755))
filesystems.push(Fs.new('var', 'nosuid,subvol=var', 00755))
filesystems.push(Fs.new('opt', 'nosuid,subvol=opt', 00755))

filesystems.each do |fs|
  tmpdir = "/#{fs.volname}.tmp"

  directory "#{tmpdir}" do
    action :create
    not_if "df | grep /#{fs.volname}"
  end

  execute "rsync -qav /#{fs.volname}/* #{tmpdir}/" do
    only_if { Dir.exists? tmpdir }
  end

  execute "btrfs subvolume create #{rootdir}/#{fs.volname}" do
    not_if "btrfs subvolume list #{rootdir} | grep #{fs.volname}" k
  end

  mount "/#{fs.volname}" do
    device "root-btrfs"
    device_type :label
    fstype "btrfs"
    #options fs.opts + "," + dev_list.map{ |dev| "device=/dev/#{dev.fixed_dev_name}" }*","
    options fs.opts
    action [:enable, :mount]
  end

  execute "rsync -qav #{tmpdir}/* /#{fs.volname}/" do
    only_if { Dir.exists? tmpdir }
  end

  directory tmpdir do
    action :delete
    recursive true
  end

  directory "/#{fs.volname}" do
    owner "root"
    group "root"
    mode fs.perms
  end
end