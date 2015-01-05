actions :create
default_action :create

attribute :fs_type,                :kind_of => String, :name_attribute => true, :required => true
attr_accessor :exists