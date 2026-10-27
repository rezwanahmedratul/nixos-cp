# Competition allowlist for contest participants.
#
# - Administrator ('admin') and root: Always have full, unrestricted internet access.
# - Contestants: Access is restricted strictly to the domains and subnets listed below.
{ ... }:

{
  lab.networkFilter = {
    enable = true; # Set to false to disable internet restrictions

    # List of domain names that contest participants are permitted to access.
    # Subdomains (e.g. assets.codeforces.com) are automatically permitted.
    allowedDomains = [
      # Competitive Programming Judges & Platforms
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

      # Add your university contest platform or judge:
      # "domjudge.cse.myuniversity.edu"
    ];

    # Local subnets accessible by contestants (LAN judges, campus network):
    allowedIPs = [
      "127.0.0.0/8"      # Local loopback
      "10.0.0.0/8"       # Campus network
      "172.16.0.0/12"    # Private LAN
      "192.168.0.0/16"   # Local contest servers (e.g. DOMjudge, PC2)
    ];
  };
}
