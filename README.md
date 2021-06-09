# scripts
Just a script repo for now.

If you arent root, you should run `sudo su` first for any script that requires it

**Pterodactyl Database & .env Backup**
```bash
# root reccomended
curl -SsL https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/backup_panel.sh | bash -s -- <optional-backup-location>
```
**Dynmap Proxy Creation Tool for Nginx or Apache** (untested)
```bash
# root required
curl -SsL https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/create_dynmap_proxy.sh | bash
```

**Pterodactyl Updater** (untested)

Update your panel, even if its all the way back in 0.6!
```bash
# root required
curl -SsL https://raw.githubusercontent.com/TekExplorer/scripts/main/ptero/update_ptero.sh | bash -s -- -a
```
