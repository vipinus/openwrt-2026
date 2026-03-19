# openwrt-2026
OpenWRT 24.x custom firmware with OpenConnect VPN

## VPN Features
- OpenConnect (AnyConnect compatible) protocol
- Auto-fetch server certificate before connection
- Random port (50000-59999) for each connection
- Split tunneling (domestic IP direct, foreign IP via VPN)
- Auto-reconnect on authentication valid

## Server Selection
- Servers fetched dynamically from API
- User selects country/server from LuCI interface
- Supports 30+ countries worldwide

## Supported Models
876+ router models from OpenWRT 24.10.0 official support
