# scripts
Just a script repo for now.

If you arent root, you should run `sudo su` first for any script that requires it

**Pterodactyl Database & .env Backup**
```bash
# root reccomended
bash <(curl -Ss https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/backup_panel.sh) <optional-backup-location>
```
**Dynmap Proxy Creation Tool for Nginx or Apache** (untested)
```bash
# root required
bash <(curl -Ss https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/create_dynmap_proxy.sh)
```

**Pterodactyl Updater** (untested)
```bash
# root required
bash <(curl -Ss https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/update_ptero.sh)
```
