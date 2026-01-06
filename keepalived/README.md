# Keepalived

## Overview

Keepalived is a routing software providing high availability and load balancing using the VRRP (Virtual Router Redundancy Protocol) protocol. It allows multiple servers to share a virtual IP address, with automatic failover if the master server becomes unavailable.

### Key Concepts

- **Virtual IP (VIP)**: A shared IP address that floats between servers
- **VRRP**: Protocol for automatic failover between MASTER and BACKUP nodes
- **Priority**: Determines which server becomes MASTER (higher priority wins)
- **Virtual Router ID**: Must be identical across all nodes in the same VRRP instance

## Basic Configuration Examples

### MASTER Configuration

```
vrrp_instance TEST_1 {
  state MASTER
  interface ens18
  virtual_router_id 100
  priority 100
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass Letmein1
  }
  virtual_ipaddress {
    172.16.0.150
  }
}
```

### BACKUP Configuration

The BACKUP node has a lower priority (90 vs 100) and will take over if the MASTER fails.

```
vrrp_instance TEST_1 {
  state BACKUP
  interface ens18
  virtual_router_id 100
  priority 90
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass Letmein1
  }
  virtual_ipaddress {
    172.16.0.150
  }
}
```


# Tracking processes

If Apache2 stops running, then the priority will drop to 100 and trigger a failover

```
vrrp_track_process track_apache {
      process apache2
      weight 10
}


vrrp_instance TEST_1 {
  state MASTER
  interface ens18
  virtual_router_id 100
  priority 100
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass Letmein1
  }
  virtual_ipaddress {
    172.16.0.150
  }
  track_process {
    track_apache
  }
}
```


```
vrrp_track_process track_apache {
      process apache2
      weight 10
}


vrrp_instance TEST_1 {
  state BACKUP
  interface ens18
  virtual_router_id 100
  priority 95
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass Letmein1
  }
  virtual_ipaddress {
    172.16.0.150
  }
  track_process {
    track_apache
  }
}
```



# Tracking files



```
server1# cat keepalived.conf
vrrp_track_file track_app_file {
      file /var/run/my_app/vrrp_track_file
}

vrrp_instance VI_1 {
      state MASTER
      interface eth0
      virtual_router_id 51
      priority 244
      advert_int 1
      authentication {
         auth_type PASS
         auth_pass 12345
      }
      virtual_ipaddress {
         192.168.122.200/24
      }
      track_file {
         track_app_file weight 1
   }
}
```

You can see that the advertised priority is 249, which is the value in the file (5) multiplied by the weight (1) and added to the base priority (244). Similarly, adjusting the priority to 6 will increase the priority.

```
server1# mkdir /var/run/my_app
server1# echo 5 > /var/run/my_app/vrrp_track_file
server1# systemctl restart keepalived
server1# tcpdump proto 112
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
16:19:32.191562 IP server1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 249, authtype simple, intvl 1s, length 20
```

## Tracking Scripts

You can use custom scripts to perform health checks and trigger failovers based on application-specific conditions.

```bash
vrrp_script check_api {
    script "/usr/local/bin/check_api.sh"
    interval 5       # Check every 5 seconds
    weight -20       # Reduce priority by 20 if script fails
    fall 3           # Require 3 failures before marking as down
    rise 2           # Require 2 successes before marking as up
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass secret123
    }
    virtual_ipaddress {
        192.168.1.100
    }
    track_script {
        check_api
    }
}
```

Example health check script (`/usr/local/bin/check_api.sh`):

```bash
#!/bin/bash
# Check if API is responding
curl -sf http://localhost:8080/health > /dev/null 2>&1
exit $?
```

## Multiple Virtual IPs

You can configure multiple virtual IP addresses for the same VRRP instance:

```
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    virtual_ipaddress {
        192.168.1.100
        192.168.1.101
        10.0.0.50/24 dev eth1
    }
}
```

## Unicast Mode

By default, Keepalived uses multicast. For environments where multicast is blocked, use unicast:

```
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    unicast_src_ip 192.168.1.10    # This server's IP
    unicast_peer {
        192.168.1.11                # BACKUP server IP
        192.168.1.12                # Another BACKUP server IP
    }
    virtual_ipaddress {
        192.168.1.100
    }
}
```

## Troubleshooting

### Check Keepalived Status

```bash
# Check service status
systemctl status keepalived

# View logs
journalctl -u keepalived -f

# Check current VRRP state
ip addr show | grep -A 2 "inet.*scope global"
```

### Common Issues

#### 1. Split-Brain (Both nodes become MASTER)

**Symptoms**: Both servers have the VIP assigned simultaneously.

**Causes**:
- Firewall blocking VRRP multicast traffic (224.0.0.18)
- Network issues between nodes
- Different `virtual_router_id` values

**Solutions**:
```bash
# Allow VRRP protocol (IP protocol 112)
iptables -A INPUT -p vrrp -j ACCEPT
iptables -A OUTPUT -p vrrp -j ACCEPT

# Verify VRRP traffic
tcpdump -i eth0 proto 112
```

#### 2. VIP Not Assigned

**Check**:
```bash
# Verify interface configuration
ip addr show

# Check VRRP advertisements
tcpdump -i eth0 -n proto 112

# Verify priority and state
grep -E "priority|state" /etc/keepalived/keepalived.conf
```

#### 3. Failover Not Triggering

**Debug**:
```bash
# Enable debug logging
keepalived -D -d -S 7

# Check track script output
/usr/local/bin/check_api.sh
echo $?  # Should be 0 for success

# Verify script permissions
ls -l /usr/local/bin/check_api.sh  # Should be executable
```

#### 4. Authentication Failures

Ensure `auth_pass` is identical on all nodes and max 8 characters:

```
authentication {
    auth_type PASS
    auth_pass 12345678  # Max 8 characters
}
```

### Monitoring Commands

```bash
# Monitor VRRP advertisements
tcpdump -vvv -i eth0 proto 112

# Check which node is MASTER
ip addr show | grep "inet.*scope global.*secondary"

# View real-time keepalived activity
tail -f /var/log/syslog | grep Keepalived

# Check configuration syntax
keepalived -t -f /etc/keepalived/keepalived.conf
```

### Best Practices

1. **Use unicast mode** in cloud environments where multicast may be blocked
2. **Set different priorities** on each node to control failover order
3. **Monitor track scripts** carefully - ensure they're fast and reliable
4. **Use authentication** to prevent rogue VRRP instances
5. **Test failover** regularly by stopping keepalived on the MASTER
6. **Keep advert_int low** (1 second) for faster failover detection
7. **Use track_script over track_process** for more control and flexibility

## Configuration File Location

- **Debian/Ubuntu**: `/etc/keepalived/keepalived.conf`
- **RHEL/CentOS**: `/etc/keepalived/keepalived.conf`

## Service Management

```bash
# Start keepalived
systemctl start keepalived

# Enable on boot
systemctl enable keepalived

# Restart after config changes
systemctl restart keepalived

# Check configuration syntax before restarting
keepalived -t && systemctl restart keepalived
```

