# unmount the default storage from vanilla ubuntu ami
mount "/mnt" do
  device "/dev/xvdb"
  action [:umount, :disable]
  ignore_failure true
end