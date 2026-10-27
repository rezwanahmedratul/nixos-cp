{
  lib,
  swapSize ? "4G",
  ...
}:

{
  disko.devices.disk.main = {
    # Default target drive; override with /dev/nvme0n1 if lab machines use NVMe
    device = lib.mkDefault "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          end = "-${swapSize}"; # Leaves exact swap size at the end of the disk
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
        swap = {
          size = "100%"; # Consumes remaining space for swap
          content = {
            type = "swap";
            discardPolicy = "both";
            resumeDevice = false; # No hibernation needed
          };
        };
      };
    };
  };
}
