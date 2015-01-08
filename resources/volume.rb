actions :create
default_action :create

attribute :fs_type,                :kind_of => String
attribute :raid_type,              :kind_of => String
attribute :volume_label,           :kind_of => String, :name_attribute => true, :required => true
attribute :devices,                :kind_of => Array
attribute :mount,                  :kind_of => Boolean

attr_accessor :exists