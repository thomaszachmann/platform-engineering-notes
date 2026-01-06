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



