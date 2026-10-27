{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.lab.networkFilter;
  participant = config.lab.user;

  # Helper script to allow a domain (and its subdomains) on the fly during a live contest
  allowDomainScript = pkgs.writeShellScriptBin "contest-allow-domain" ''
    set -euo pipefail
    if [ "$#" -ne 1 ]; then
      echo "Usage: sudo contest-allow-domain <domain.com>"
      exit 1
    fi
    DOMAIN="$1"
    echo "Adding $DOMAIN and subdomains to contest ipsets..."
    ${pkgs.ipset}/bin/ipset create contest_allowed hash:net family inet -exist
    ${pkgs.ipset}/bin/ipset create contest_allowed6 hash:net family inet6 -exist
    FOUND=0
    for ip in $(getent ahosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | sort -u); do
      if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "  -> Whitelisting IPv4: $ip ($DOMAIN)"
        ${pkgs.ipset}/bin/ipset add contest_allowed "$ip" -exist || true
        FOUND=1
      elif echo "$ip" | grep -q ':'; then
        echo "  -> Whitelisting IPv6: $ip ($DOMAIN)"
        ${pkgs.ipset}/bin/ipset add contest_allowed6 "$ip" -exist || true
        FOUND=1
      fi
    done
    if [ "$FOUND" -eq 1 ]; then
      echo "Domain $DOMAIN successfully whitelisted for contestants."
    else
      echo "Warning: Could not resolve IP addresses for $DOMAIN. Please check domain name."
    fi
  '';

  # Helper script to inspect current network filtering status
  statusScript = pkgs.writeShellScriptBin "contest-network-status" ''
    echo "=== Contest Network Filter Status ==="
    echo "Participant user : ${participant}"
    echo "Filter enabled   : ${if cfg.enable then "YES (Restricted to whitelist & subdomains)" else "NO (Unrestricted internet)"}"
    echo ""
    echo "--- Allowed Domains (configured; all subdomains automatically allowed) ---"
    ${lib.concatMapStringsSep "\n" (d: "echo '  * ${d}'") cfg.allowedDomains}
    echo ""
    echo "--- Allowed Subnets (configured) ---"
    ${lib.concatMapStringsSep "\n" (ip: "echo '  * ${ip}'") cfg.allowedIPs}
    echo ""
    echo "--- Currently Whitelisted IPv4 IPs (kernel ipset: contest_allowed) ---"
    if ${pkgs.ipset}/bin/ipset list contest_allowed &>/dev/null; then
      ${pkgs.ipset}/bin/ipset list contest_allowed | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 30 || true
      COUNT4=$(${pkgs.ipset}/bin/ipset list contest_allowed 2>/dev/null | grep -c -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "0")
      echo "Total active IPv4 IPs in whitelist: $COUNT4"
    else
      echo "No active IPv4 ipset found."
    fi
    echo ""
    echo "--- Currently Whitelisted IPv6 IPs (kernel ipset: contest_allowed6) ---"
    if ${pkgs.ipset}/bin/ipset list contest_allowed6 &>/dev/null; then
      ${pkgs.ipset}/bin/ipset list contest_allowed6 | grep ':' | head -n 30 || true
      COUNT6=$(${pkgs.ipset}/bin/ipset list contest_allowed6 2>/dev/null | grep -c ':' || echo "0")
      echo "Total active IPv6 IPs in whitelist: $COUNT6"
    else
      echo "No active IPv6 ipset found."
    fi
  '';

  # Startup and periodic seeding script
  seedScript = pkgs.writeShellScript "seed-contest-ipset" ''
    set -euo pipefail
    ${pkgs.ipset}/bin/ipset create contest_allowed hash:net family inet -exist
    ${pkgs.ipset}/bin/ipset create contest_allowed6 hash:net family inet6 -exist

    # Add allowed IPv4 subnets
    ${lib.concatMapStringsSep "\n" (
      ip: "${pkgs.ipset}/bin/ipset add contest_allowed ${ip} -exist"
    ) cfg.allowedIPs}

    # Resolve and add allowed domains (both IPv4 and IPv6)
    ${lib.concatMapStringsSep "\n" (domain: ''
      for ip in $(getent ahosts "${domain}" 2>/dev/null | awk '{print $1}' | sort -u); do
        if echo "$ip" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
          ${pkgs.ipset}/bin/ipset add contest_allowed "$ip" -exist || true
        elif echo "$ip" | grep -q ':'; then
          ${pkgs.ipset}/bin/ipset add contest_allowed6 "$ip" -exist || true
        fi
      done
    '') cfg.allowedDomains}
  '';
in {
  options.lab.networkFilter = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to restrict internet access for the contest participant.
        When true, contestants are restricted to whitelisted domains (including all subdomains)
        and private LAN, while admin and root retain full, unrestricted internet access.
      '';
    };

    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Standard Competitive Programming platforms, mirrors & subdomains
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

        # Cloudflare Verification & Turnstile (required for bot check challenges on CP sites)
        "cloudflare.com"
        "challenges.cloudflare.com"

        # Web fonts & CDN assets commonly used by CP platforms
        "fonts.googleapis.com"
        "fonts.gstatic.com"
        "cdnjs.cloudflare.com"
      ];
      description = "List of domain names that contest participants are permitted to access. Subdomains are automatically permitted.";
    };

    allowedIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "127.0.0.0/8"      # Loopback
        "10.0.0.0/8"       # Campus / Private LAN
        "172.16.0.0/12"    # Private LAN
        "192.168.0.0/16"   # Local contest servers (e.g. DOMjudge, PC2)
      ];
      description = "List of subnets/CIDRs accessible by contest participants.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.ipset
      allowDomainScript
      statusScript
    ];

    # Local DNS resolver with dynamic ipset population for both IPv4 and IPv6
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        interface = [ "lo" ];
        bind-interfaces = true;
        listen-address = [ "127.0.0.1" "::1" ];
        cache-size = 1000;
        server = [ "1.1.1.1" "8.8.8.8" ];
        # Automatically insert resolved IPs of whitelisted domains AND any of their subdomains
        # into both contest_allowed (IPv4) and contest_allowed6 (IPv6) in real time
        ipset = map (domain: "/${domain}/contest_allowed,contest_allowed6") cfg.allowedDomains;
      };
    };

    # Run dnsmasq as root (without --user=dnsmasq) so that it retains CAP_NET_ADMIN to
    # dynamically add resolved IPs of any queried subdomain into the kernel ipsets.
    systemd.services.dnsmasq.serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.dnsmasq}/bin/dnsmasq -k --enable-dbus -C ${config.services.dnsmasq.configFile}";
    };

    # Systemd service to seed the ipset at boot
    systemd.services.contest-ipset-seed = {
      description = "Seed contest_allowed ipset with whitelisted domains";
      after = [ "network-online.target" "dnsmasq.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${seedScript}";
        RemainAfterExit = true;
      };
    };

    # Refresh whitelisted domain IPs every 30 minutes
    systemd.timers.contest-ipset-refresh = {
      description = "Periodic refresh of contest whitelisted domain IPs";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = "30min";
        Unit = "contest-ipset-seed.service";
      };
    };

    # Firewall per-user rules (both IPv4 and IPv6)
    networking.firewall = {
      enable = true;

      extraCommands = ''
        # Ensure kernel ipsets exist
        ${pkgs.ipset}/bin/ipset create contest_allowed hash:net family inet -exist
        ${pkgs.ipset}/bin/ipset create contest_allowed6 hash:net family inet6 -exist

        # Add pre-configured subnets into contest_allowed
        ${lib.concatMapStringsSep "\n" (
          ip: "${pkgs.ipset}/bin/ipset add contest_allowed ${ip} -exist"
        ) cfg.allowedIPs}

        # Create or flush dedicated CONTEST_OUT chain in both iptables and ip6tables
        iptables -N CONTEST_OUT 2>/dev/null || iptables -F CONTEST_OUT
        ip6tables -N CONTEST_OUT 2>/dev/null || ip6tables -F CONTEST_OUT

        # Admin, Root, and system daemons bypass all restrictions: FULL INTERNET
        iptables -A CONTEST_OUT -m owner ! --uid-owner "${participant}" -j ACCEPT
        ip6tables -A CONTEST_OUT -m owner ! --uid-owner "${participant}" -j ACCEPT

        # Contestant IPv4 rules:
        # 1. Allow loopback
        iptables -A CONTEST_OUT -o lo -j ACCEPT

        # 2. Allow established & related traffic
        iptables -A CONTEST_OUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # 3. Allow DNS queries only to local dnsmasq (127.0.0.1:53)
        iptables -A CONTEST_OUT -p udp -d 127.0.0.1 --dport 53 -j ACCEPT
        iptables -A CONTEST_OUT -p tcp -d 127.0.0.1 --dport 53 -j ACCEPT

        # 4. Block external DNS queries (prevents bypassing local resolver)
        iptables -A CONTEST_OUT -p udp --dport 53 -j REJECT --reject-with icmp-admin-prohibited
        iptables -A CONTEST_OUT -p tcp --dport 53 -j REJECT --reject-with icmp-admin-prohibited

        # 5. Allow traffic to whitelisted destinations (including all subdomains dynamically added by dnsmasq)
        iptables -A CONTEST_OUT -m set --match-set contest_allowed dst -j ACCEPT

        # 6. Reject all other outbound traffic for contestant
        iptables -A CONTEST_OUT -j REJECT --reject-with icmp-admin-prohibited

        # Contestant IPv6 rules:
        # 1. Allow loopback
        ip6tables -A CONTEST_OUT -o lo -j ACCEPT

        # 2. Allow established & related traffic
        ip6tables -A CONTEST_OUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # 3. Allow DNS queries only to local dnsmasq (::1:53)
        ip6tables -A CONTEST_OUT -p udp -d ::1 --dport 53 -j ACCEPT
        ip6tables -A CONTEST_OUT -p tcp -d ::1 --dport 53 -j ACCEPT

        # 4. Block external DNS queries
        ip6tables -A CONTEST_OUT -p udp --dport 53 -j REJECT --reject-with icmp6-adm-prohibited
        ip6tables -A CONTEST_OUT -p tcp --dport 53 -j REJECT --reject-with icmp6-adm-prohibited

        # 5. Allow traffic to whitelisted destinations (including all subdomains dynamically added by dnsmasq)
        ip6tables -A CONTEST_OUT -m set --match-set contest_allowed6 dst -j ACCEPT

        # 6. Reject all other outbound IPv6 traffic for contestant
        ip6tables -A CONTEST_OUT -j REJECT --reject-with icmp6-adm-prohibited

        # Attach CONTEST_OUT at the head of the OUTPUT chains
        iptables -C OUTPUT -j CONTEST_OUT 2>/dev/null || iptables -I OUTPUT 1 -j CONTEST_OUT
        ip6tables -C OUTPUT -j CONTEST_OUT 2>/dev/null || ip6tables -I OUTPUT 1 -j CONTEST_OUT
      '';

      extraStopCommands = ''
        iptables -D OUTPUT -j CONTEST_OUT 2>/dev/null || true
        iptables -F CONTEST_OUT 2>/dev/null || true
        iptables -X CONTEST_OUT 2>/dev/null || true

        ip6tables -D OUTPUT -j CONTEST_OUT 2>/dev/null || true
        ip6tables -F CONTEST_OUT 2>/dev/null || true
        ip6tables -X CONTEST_OUT 2>/dev/null || true
      '';
    };

    # Disable DNS-Over-HTTPS in Firefox so browser uses system dnsmasq
    programs.firefox.policies = {
      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };
    };
  };
}
