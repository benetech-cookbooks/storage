require 'net/http'

class EphemeralStorage
  @@filesystems = [ 'root',
                    'tmp',
                    'home',
                    'var' ]
  @@mount_point_perms = { root => 00755,
                          tmp  => 01777,
                          home => 00755,
                          var  => 00755 }
  @@root_dir = "/ephemeral"
  @@fs_type = "none"
  @dev_list =

  def initialize
    @dev_list = find_ephemeral_devices
  end

  def self.find_ephemeral_devices
    metadata_host = '169.254.169.254'
    block_dev_map_path = '/latest/meta-data/block-device-mapping/'
    dev_size_cmd = "blockdev --getsize64"
    dev_list = []
    aws_dev_list = Net::HTTP.get_response(metadata_host, block_dev_map_path)

    # Create an array of Dev objects
    aws_dev_list.body.split("\n").each do |aws_dev|
      next if aws_dev.eql? "root" || "ami"
      new_dev = OpenStruct.new
      new_dev.aws_name = aws_dev
      new_dev.dev_name = Net::HTTP.get_response(metadata_host, "#{block_dev_map_path}/#{aws_dev}").body
      new_dev.fixed_dev_name = "xv#{new_dev.dev_name.dup[1..-1]}"
      new_dev.size_bytes = `#{dev_size_cmd} /dev/#{new_dev.fixed_dev_name}`
      dev_list.push(new_dev)
    end

    return dev_list
  end

  def self.destroy_default_dev
    # WTF does Amazon format/mount one random device initially?  Idiots...
    mount "/mnt" do
      device "/dev/xvdb"
      action [:umount, :disable]
    end
  end

  def dev_list
    @dev_list
  end

  def root_dir
    @@root_dir
  end

  def fs_opts
    @@fs_opts
  end

  def clone_existing_content
    @@filesystems.each do |fs|
      tmpdir = "/#{fs}.tmp"

      directory "#{tmpdir}" do
        action :create
        not_if "df | grep /#{volname}"
      end

      execute "rsync -qav /#{fs}/* #{tmpdir}/" do
        only_if { Dir.exists? tmpdir }
      end

      ################### STOPPED HERE #######################
      ### Where does the following block belong? In a subclass?



      mount "/#{fs.volname}" do
        device "root-btrfs"
        device_type :label
        fstype "btrfs"
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
  end
end