# microsocks + LuCI for QWRT

This project repackages the official `microsocks` OpenWrt package with a minimal LuCI web interface for QWRT (and other Lua-based LuCI firmwares).

## Features

- **LuCI Web UI**: Services → microsocks page to configure all options
- **Init.d integration**: Enabling the service via UI automatically enables and starts/restarts the daemon
- **Configuration options**:
  - Enabled (on/off)
  - Listen IP (default: `::`)
  - Listen port (default: `1080`)
  - Outgoing bind address (optional)
  - Username / Password (optional authentication)
  - Authenticate once (boolean)
  - Allow WAN access (boolean, requires firewall support in init script)

## Requirements

- QWRT or OpenWrt with **Lua-based LuCI** (older stack without ucode dispatcher)
- `luci-base` and standard LuCI admin UI installed
- Architecture: `aarch64_cortex-a53` (adjust as needed)

## Files

```
luci-app-microsocks/
├── root/
│   ├── usr/
│   │   ├── lib/lua/luci/
│   │   │   ├── controller/microsocks.lua    # Lua controller
│   │   │   └── model/cbi/microsocks.lua     # CBI form model
│   │   └── share/
│   │       ├── luci/menu.d/luci-app-microsocks.json
│   │       └── rpcd/acl.d/luci-app-microsocks.json
│   └── www/luci-static/resources/view/microsocks/
│       └── microsocks.js                     # JS view (for newer LuCI)
├── htdocs/luci-static/resources/view/microsocks/
│   └── microsocks.js
├── po/templates/microsocks.pot
└── Makefile
```

## Build

### Using the repack script

```sh
cd /Users/alejandro/Documents/microsocks
./repack-microsocks-ipk.sh [path/to/original.ipk]
```

Output: `microsocks_1.0.4-2_aarch64_cortex-a53+luci.ipk`

### Manual build (SDK)

Place `luci-app-microsocks` in the LuCI `applications/` directory and build with the OpenWrt SDK.

## Install

```sh
opkg install --force-reinstall /tmp/microsocks_1.0.4-2_aarch64_cortex-a53+luci.ipk
rm -f /tmp/luci-indexcache /tmp/luci-indexcache.* /tmp/luci-modulecache/*
/etc/init.d/uhttpd restart
```

## Usage

1. Open LuCI: `http://<router-ip>/cgi-bin/luci`
2. Navigate to **Services → microsocks**
3. Configure options and click **Save & Apply**
4. When **Enabled** is checked, the service will be enabled on boot and started/restarted automatically

## Troubleshooting

- **"No page is registered"**: Clear LuCI caches and restart uhttpd:
  ```sh
  rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/*
  /etc/init.d/uhttpd restart
  ```
- **`ucode: not found`**: Your firmware uses Lua-based LuCI. The controller/CBI files are required (included in this package).
- **Service not starting**: Check logs:
  ```sh
  logread | grep microsocks
  /etc/init.d/microsocks restart
  ```

## License

- microsocks: MIT
- LuCI integration: GPL-2.0
