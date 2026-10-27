{ pkgs, lib, ... }:

{
  # Precise NTP time synchronization across all lab machines
  services.timesyncd.enable = true;

  # OpenSSH server for remote lab management
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Modern audio architecture (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Anti-interruption: Disable sleep/suspend during thinking time in contests
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };
}
