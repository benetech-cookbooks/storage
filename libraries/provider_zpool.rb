require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'zfs'

class Chef
  class Provider
    class Zpool < Chef::Provider::LWRPBase
      include StorageCookbook::Zfs

      use_inline_resources if defined?(use_inline_resources)

      action :create do
        if @current_resource.exists
          Chef::Log.info "#{ @new_resource } already exists - nothing to do."
        else
          converge_by("Create #{ @new_resource }") do
            name = @new_resource.vol_name
            raid_level = @new_resource.raid_level
            devices = @new_resource.devices
            mount_point = @new_resource.mount_point

            directory mount_point do
              action :create
            end

            create_zpool(name, raid_level, devices, { :mount_point => mount_point })
          end
        end
      end

      def load_current_resource
        @current_resource = Chef::Resource::Zpool.new(@new_resource.name)
        @current_resource.name(@new_resource.name)
        @current_resource.raid_level
        @current_resource.mount_point                                                                                                                s
        if zpool_exists?(@current_resource.name)
          # TODO: Set @current_resource port properties from registry
          @current_resource.exists = true
        end
      end

      def whyrun_supported?
        true
      end

      def configure_base_fs(root_vol_name, filesystems)
        filesystems.each do |subvol, opts|
          next if subvol.eql? "root"

          tmpdir = "/#{subvol}.tmp"
          subvol_lookup_cmd = "zfs list | grep -q #{root_vol_name}/#{subvol}"

          if ! Mixlib::ShellOut.new(subvol_lookup_cmd).run_command
            create_subvolume(root_vol_name, subvol, mount_point: tmpdir)
          end

          cmd = Mixlib::ShellOut.new("rsync -qav /#{subvol}/ #{tmpdir}/")
          cmd.run_command.error!

          cmd = Mixlib::ShellOut.new("mv /#{subvol} /#{subvol}.off")
          cmd.run_command.error!

          cmd = Mixlib::ShellOut.new("zfs set mountpoint=/#{subvol} #{root_vol_name}/#{subvol}")
          cmd.run_command.error!

          cmd = Mixlib::ShellOut.new("mv /#{subvol} /#{subvol}.off")
          cmd.run_command.error!

          cmd = Mixlib::ShellOut.new("zfs set mountpoint=/#{subvol} #{root_vol_name}/#{subvol}")
          cmd.run_command.error!

          directory "tmp_#{tmpdir}" do
            path tmpdir
            recursive true
          end

          cmd = Mixlib::ShellOut.new("zfs set #{option} #{root_vol_name}/#{subvol}")
          cmd.run_command.error!

          directory "subvol_root_#{subvol}" do
            path "/#{subvol}"
            owner "root"
            group "root"
            mode filesystems[subvol][0]
            only_if { Dir.exist? "/#{subvol}"}
          end
        end
      end

      def create_zpool(volume_name, raid_level, devices, options = {})
        dev_list_string = StorageCookbook::Utils.dev_string_from_array(devices)

        opts_string = ''
        opts_string = opts_string + " -m #{options[:mount_point]}" unless options[:mount_point].nil?

        create_pool_cmd = Mixlib::ShellOut.new("zpool create -f#{opts_string} #{volume_name} #{raid_level} #{dev_list_string}")
        create_pool_cmd.run_command.error!
      end

      def zpool_exists?(name)
        cmd = Mixlib::ShellOut.new("zpool list | grep -q #{name}")
        return cmd.run_command.status
      end
    end
  end
end