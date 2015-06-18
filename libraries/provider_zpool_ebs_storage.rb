require 'chef/provider/lwrp_base'
require_relative 'ephemeral_storage'
require_relative 'zfs'

class Chef
  class Provider
    class ZpoolEbs < Chef::Provider::LWRPBase
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
    end
  end
end