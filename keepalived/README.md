# Keepalived

## Übersicht

Keepalived ist eine Routing-Software, die hohe Verfügbarkeit und Load Balancing mithilfe des VRRP-Protokolls (Virtual Router Redundancy Protocol) bereitstellt. Sie ermöglicht es mehreren Servern, eine virtuelle IP-Adresse gemeinsam zu nutzen, mit automatischem Failover, falls der Master-Server nicht verfügbar ist.

### Wichtige Konzepte

- **Virtual IP (VIP)**: Eine gemeinsam genutzte IP-Adresse, die zwischen Servern wechselt
- **VRRP**: Protokoll für automatisches Failover zwischen MASTER- und BACKUP-Knoten
- **Priorität**: Bestimmt, welcher Server MASTER wird (höhere Priorität gewinnt)
- **Virtual Router ID**: Muss auf allen Knoten derselben VRRP-Instanz identisch sein

## Grundlegende Konfigurationsbeispiele

### MASTER-Konfiguration

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

### BACKUP-Konfiguration

Der BACKUP-Knoten hat eine niedrigere Priorität (90 vs. 100) und übernimmt, wenn der MASTER ausfällt.

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


# Prozesse überwachen

Wenn Apache2 nicht mehr läuft, sinkt die Priorität auf 100 und löst ein Failover aus

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



# Dateien überwachen



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

Sie können sehen, dass die angekündigte Priorität 249 beträgt. Dies ist der Wert in der Datei (5), multipliziert mit dem Gewicht (1) und addiert zur Basispriorität (244). Ebenso erhöht das Anpassen der Priorität auf 6 die Gesamtpriorität.

```
server1# mkdir /var/run/my_app
server1# echo 5 > /var/run/my_app/vrrp_track_file
server1# systemctl restart keepalived
server1# tcpdump proto 112
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
16:19:32.191562 IP server1 > vrrp.mcast.net: VRRPv2, Advertisement, vrid 51, prio 249, authtype simple, intvl 1s, length 20
```

## Skripte überwachen

Sie können benutzerdefinierte Skripte verwenden, um Health Checks durchzuführen und Failovers basierend auf anwendungsspezifischen Bedingungen auszulösen.

```bash
vrrp_script check_api {
    script "/usr/local/bin/check_api.sh"
    interval 5       # Alle 5 Sekunden prüfen
    weight -20       # Priorität um 20 reduzieren, wenn Skript fehlschlägt
    fall 3           # 3 Fehlschläge erforderlich, bevor als ausgefallen markiert
    rise 2           # 2 Erfolge erforderlich, bevor als aktiv markiert
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

Beispiel für ein Health-Check-Skript (`/usr/local/bin/check_api.sh`):

```bash
#!/bin/bash
# Prüfen, ob API antwortet
curl -sf http://localhost:8080/health > /dev/null 2>&1
exit $?
```

## Mehrere virtuelle IPs

Sie können mehrere virtuelle IP-Adressen für dieselbe VRRP-Instanz konfigurieren:

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

## Unicast-Modus

Standardmäßig verwendet Keepalived Multicast. Für Umgebungen, in denen Multicast blockiert ist, verwenden Sie Unicast:

```
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    unicast_src_ip 192.168.1.10    # IP dieses Servers
    unicast_peer {
        192.168.1.11                # BACKUP-Server-IP
        192.168.1.12                # Weitere BACKUP-Server-IP
    }
    virtual_ipaddress {
        192.168.1.100
    }
}
```

## Fehlerbehebung

### Keepalived-Status überprüfen

```bash
# Service-Status prüfen
systemctl status keepalived

# Logs anzeigen
journalctl -u keepalived -f

# Aktuellen VRRP-Status prüfen
ip addr show | grep -A 2 "inet.*scope global"
```

### Häufige Probleme

#### 1. Split-Brain (Beide Knoten werden MASTER)

**Symptome**: Beide Server haben gleichzeitig die VIP zugewiesen.

**Ursachen**:
- Firewall blockiert VRRP-Multicast-Traffic (224.0.0.18)
- Netzwerkprobleme zwischen Knoten
- Unterschiedliche `virtual_router_id`-Werte

**Lösungen**:
```bash
# VRRP-Protokoll erlauben (IP-Protokoll 112)
iptables -A INPUT -p vrrp -j ACCEPT
iptables -A OUTPUT -p vrrp -j ACCEPT

# VRRP-Traffic überprüfen
tcpdump -i eth0 proto 112
```

#### 2. VIP nicht zugewiesen

**Prüfen**:
```bash
# Interface-Konfiguration überprüfen
ip addr show

# VRRP-Ankündigungen prüfen
tcpdump -i eth0 -n proto 112

# Priorität und Status überprüfen
grep -E "priority|state" /etc/keepalived/keepalived.conf
```

#### 3. Failover wird nicht ausgelöst

**Debugging**:
```bash
# Debug-Logging aktivieren
keepalived -D -d -S 7

# Track-Skript-Ausgabe prüfen
/usr/local/bin/check_api.sh
echo $?  # Sollte 0 für Erfolg sein

# Skript-Berechtigungen überprüfen
ls -l /usr/local/bin/check_api.sh  # Sollte ausführbar sein
```

#### 4. Authentifizierungsfehler

Stellen Sie sicher, dass `auth_pass` auf allen Knoten identisch ist und maximal 8 Zeichen hat:

```
authentication {
    auth_type PASS
    auth_pass 12345678  # Max. 8 Zeichen
}
```

### Monitoring-Befehle

```bash
# VRRP-Ankündigungen überwachen
tcpdump -vvv -i eth0 proto 112

# Prüfen, welcher Knoten MASTER ist
ip addr show | grep "inet.*scope global.*secondary"

# Keepalived-Aktivität in Echtzeit anzeigen
tail -f /var/log/syslog | grep Keepalived

# Konfigurationssyntax prüfen
keepalived -t -f /etc/keepalived/keepalived.conf
```

### Best Practices

1. **Unicast-Modus verwenden** in Cloud-Umgebungen, wo Multicast blockiert sein kann
2. **Unterschiedliche Prioritäten festlegen** auf jedem Knoten, um die Failover-Reihenfolge zu steuern
3. **Track-Skripte sorgfältig überwachen** - sicherstellen, dass sie schnell und zuverlässig sind
4. **Authentifizierung verwenden**, um unerwünschte VRRP-Instanzen zu verhindern
5. **Failover regelmäßig testen**, indem Keepalived auf dem MASTER gestoppt wird
6. **advert_int niedrig halten** (1 Sekunde) für schnellere Failover-Erkennung
7. **track_script statt track_process verwenden** für mehr Kontrolle und Flexibilität

## Speicherort der Konfigurationsdatei

- **Debian/Ubuntu**: `/etc/keepalived/keepalived.conf`
- **RHEL/CentOS**: `/etc/keepalived/keepalived.conf`

## Service-Verwaltung

```bash
# Keepalived starten
systemctl start keepalived

# Beim Booten aktivieren
systemctl enable keepalived

# Nach Konfigurationsänderungen neu starten
systemctl restart keepalived

# Konfigurationssyntax vor dem Neustart prüfen
keepalived -t && systemctl restart keepalived
```

