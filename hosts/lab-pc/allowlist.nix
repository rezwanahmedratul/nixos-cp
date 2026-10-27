# Competition allowlist for contest participants.
#
# - Administrator ('admin') and root: Always have full, unrestricted internet access.
# - Contestants: Access is restricted strictly to the domains and subnets listed below.
#
# Note: You only need to specify the base domain (e.g. "codeforces.com").
# ALL subdomains (e.g. "m1.codeforces.com", "m2.codeforces.com", "assets.codeforces.com")
# are automatically and dynamically permitted by dnsmasq in real time.
{ ... }:

{
  lab.networkFilter = {
    enable = true; # Set to false to disable internet restrictions

    # List of allowed domain names.
    # All subdomains (e.g. m1.codeforces.com, open.kattis.com, etc.) are automatically allowed.
    allowedDomains = [
      # Competitive Programming Judges & Platforms
      "codeforces.com"
      "codeforces.org"
      "kattis.com"
      "atcoder.jp"
      "cses.fi"
      "vjudge.net"
      "leetcode.com"
      "hackerrank.com"
      "spoj.com"
      "icpc.global"
      

      # Cloudflare verification (required for Codeforces bot check challenges)
      "cloudflare.com"

      # Web fonts & CDN assets commonly used by CP platforms
      "fonts.googleapis.com"
      "fonts.gstatic.com"

      # Add your university contest platform or judge:
      # "mycontestjudge.edu"
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
