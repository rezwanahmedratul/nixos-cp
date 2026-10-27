{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.lab.networkFilter;
  participant = config.lab.user;

  # Helper script to allow a domain on the fly during a live contest
  allowDomainScript = pkgs.writeShellScriptBin "contest-allow-domain" ''
    set -euo pipefail
    if [ "$#" -ne 1 ]; then
      echo "Usage: sudo contest-allow-domain <domain.com>"
      exit 1
    fi
    DOMAIN="$1"
    echo "Adding $DOMAIN to contest_allowed ipset..."
    ${pkgs.ipset}/bin/ipset create contest_allowed hash:net -exist
    FOUND=0
    for ip in $(getent ahosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u); do
      echo "  -> Whitelisting IP: $ip ($DOMAIN)"
      ${pkgs.ipset}/bin/ipset add contest_allowed "$ip" -exist || true
      FOUND=1
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
    echo "Filter enabled   : ${if cfg.enable then "YES (Restricted to whitelist)" else "NO (Unrestricted internet)"}"
    echo ""
    echo "--- Allowed Domains (configured) ---"
    ${lib.concatMapStringsSep "\n" (d: "echo '  * ${d}'") cfg.allowedDomains}
    echo ""
    echo "--- Allowed Subnets (configured) ---"
    ${lib.concatMapStringsSep "\n" (ip: "echo '  * ${ip}'") cfg.allowedIPs}
    echo ""
    echo "--- Currently Whitelisted IPs (kernel ipset) ---"
    if ${pkgs.ipset}/bin/ipset list contest_allowed &>/dev/null; then
      ${pkgs.ipset}/bin/ipset list contest_allowed | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 30 || true
      COUNT=$(${pkgs.ipset}/bin/ipset list contest_allowed 2>/dev/null | grep -c -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "0")
      echo "Total active IPs in whitelist: $COUNT"
    else
      echo "No active ipset found."
    fi
  '';

  # Startup and periodic seeding script
  seedScript = pkgs.writeShellScript "seed-contest-ipset" ''
    set -euo pipefail
    ${pkgs.ipset}/bin/ipset create contest_allowed hash:net -exist

    # Add allowed subnets
    ${lib.concatMapStringsSep "\n" (
      ip: "${pkgs.ipset}/bin/ipset add contest_allowed ${ip} -exist"
    ) cfg.allowedIPs}

    # Resolve and add allowed domains
    ${lib.concatMapStringsSep "\n" (domain: ''
      for ip in $(getent ahosts "${domain}" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u); do
        ${pkgs.ipset}/bin/ipset add contest_allowed "$ip" -exist || true
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
        When true, contestants are restricted to whitelisted domains and private LAN,
        while admin and root retain full, unrestricted internet access.
      '';
    };

    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Standard Competitive Programming platforms & judges
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

        # Web fonts & CDN assets commonly used by CP platforms
        "fonts.googleapis.com"
        "fonts.gstatic.com"
        "cdnjs.cloudflare.com"
      ];
      description = "List of domain names that contest participants are permitted to access.";
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

    # Local DNS resolver with dynamic ipset population
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        interface = [ "lo" ];
        bind-interfaces = true;
        listen-address = [ "127.0.0.1" ];
        cache-size = 1000;
        server = [ "1.1.1.1" "8.8.8.8" ];
        # Automatically insert resolved IPs of whitelisted domains into contest_allowed ipset
        ipset = map (domain: "/${domain}/contest_allowed") cfg.allowedDomains;
      };
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

    # Firewall per-user rules
    networking.firewall = {
      enable = true;

      extraCommands = ''
        # Ensure kernel ipset exists
        ${pkgs.ipset}/bin/ipset create contest_allowed hash:net -exist

        # Add pre-configured subnets into contest_allowed
        ${lib.concatMapStringsSep "\n" (
          ip: "${pkgs.ipset}/bin/ipset add contest_allowed ${ip} -exist"
        ) cfg.allowedIPs}

        # Create or flush dedicated CONTEST_OUT chain
        iptables -N CONTEST_OUT 2>/dev/null || iptables -F CONTEST_OUT

        # Admin, Root, and system daemons bypass all restrictions: FULL INTERNET
        iptables -A CONTEST_OUT -m owner ! --uid-owner "${participant}" -j ACCEPT

        # Contestant rules:
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

        # 5. Allow traffic to whitelisted destinations in contest_allowed set
        iptables -A CONTEST_OUT -m set --match-set contest_allowed dst -j ACCEPT

        # 6. Reject all other outbound traffic for contestant
        iptables -A CONTEST_OUT -j REJECT --reject-with icmp-admin-prohibited

        # Attach CONTEST_OUT at the head of the OUTPUT chain
        iptables -C OUTPUT -j CONTEST_OUT 2>/dev/null || iptables -I OUTPUT 1 -j CONTEST_OUT
      '';

      extraStopCommands = ''
        iptables -D OUTPUT -j CONTEST_OUT 2>/dev/null || true
        iptables -F CONTEST_OUT 2>/dev/null || true
        iptables -X CONTEST_OUT 2>/dev/null || true
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
