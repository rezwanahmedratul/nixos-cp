# Competition allowlist for contest participants.
#
# - Administrator ('admin') and root: Always have full, unrestricted internet access.
# - Contestants: Access is restricted strictly to the domains and subnets listed below.
#
# Note: When a domain is specified (e.g. "codeforces.com"), all of its subdomains
# (e.g. "m1.codeforces.com", "m2.codeforces.com", "assets.codeforces.com") are
# automatically permitted and dynamically whitelisted by dnsmasq.
{ ... }:

{
  lab.networkFilter = {
    enable = true; # Set to false to disable internet restrictions

    # List of domain names that contest participants are permitted to access.
    # All subdomains (e.g. m1.codeforces.com, assets.codeforces.com) are automatically allowed.
    allowedDomains = [
      # Competitive Programming Judges, Platforms & Mirrors
      "codeforces.com"
      "codeforces.org"
      "m1.codeforces.com"
      "m2.codeforces.com"
      "m3.codeforces.com"
      "assets.codeforces.com"
      "polygon.codeforces.com"
      "espresso.codeforces.com"
      "sta.codeforces.com"

      "kattis.com"
      "open.kattis.com"
      "atcoder.jp"
      "cses.fi"
      "vjudge.net"
      "leetcode.com"
      "hackerrank.com"
      "spoj.com"
      "icpc.global"

      # Cloudflare verification & Turnstile (required for bot check challenges on CP sites)
      "cloudflare.com"
      "challenges.cloudflare.com"

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
