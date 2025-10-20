{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": ["eth1"]
    },

    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/kea-leases4.csv"
    },

    "valid-lifetime": 3600,
    "renew-timer": 900,
    "rebind-timer": 1800,

    "option-data": [
      { "name": "domain-name-servers", "data": "192.168.121.21" },
      { "name": "domain-name",         "data": "lab.mcmahon.home" }
    ],
    "client-classes": [
      {
        "name": "UEFI-64",
        "test": "option[93].exists and option[93].hex == '00:09'",
        "option-data": [{ "name": "boot-file-name", "data": "uefi/grubx64.efi" }]
      },
      {
        "name": "UEFI-BC",
        "test": "option[93].exists and option[93].hex == '00:07'",
        "option-data": [{ "name": "boot-file-name", "data": "uefi/grubx64.efi" }]
      },
      {
        "name": "UEFI-32",
        "test": "option[93].exists and option[93].hex == '00:06'",
        "option-data": [{ "name": "boot-file-name", "data": "uefi/grubia32.efi" }]
      },
      {
        "name": "BIOS",
        "test": "not option[93].exists or option[93].hex == '00:00'",
        "option-data": [{ "name": "boot-file-name", "data": "bios/pxelinux.0" }]
      }
    ],
    "subnet4": [
      {
        "id": 1,
        "subnet": "192.168.121.0/24",
        "pools": [ { "pool": "192.168.121.100 - 192.168.121.200" } ],
        "option-data": [
	  { "name": "routers", "data": "192.168.121.21" }
        ],
        "next-server": "192.168.121.21",
        "boot-file-name": "bios/pxelinux.0"
      }
    ],

    "loggers": [
      {
        "name": "kea-dhcp4",
        "output_options": [ { "output": "/var/log/kea/kea-dhcp4.log" } ],
        "severity": "INFO"
      }
    ]
  }
}

