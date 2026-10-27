{ lib, ... }:

{
  imports = [
    ../../modules/core
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # Contest participant username (configured during installation)
  lab.user = lib.mkDefault "contestant";

  # Per-user network filtering:
  # - admin & root: Full, unrestricted internet access
  # - participant: Restricted to whitelisted domains & local network
  lab.networkFilter = {
    enable = true;
    allowedDomains = [
      "codeforces.com"
      "codeforces.org"
      "kattis.com"
      "open.kattis.com"
      "atcoder.jp"
      "cses.fi"
      "vjudge.net"
      "leetcode.com"
      "hackerrank.com"
      "spoj.com"
      "icpc.global"

      # Platform asset CDNs & web fonts
      "fonts.googleapis.com"
      "fonts.gstatic.com"
      "cdnjs.cloudflare.com"
    ];
    allowedIPs = [
      "127.0.0.0/8"
      "10.0.0.0/8"
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
  };

  # Set to true for fresh installations from Live USB (Disko manages partitions).
  # Set to false on existing installed systems (hardware-configuration.nix manages filesystems).
  disko.enableConfig = lib.mkDefault true;
}

