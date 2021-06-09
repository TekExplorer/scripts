# Scripts Repo
Just a script repo for now.

If you arent root, you should run `sudo su` first for any script that requires it

## Pterodactyl Scripts

### Pterodactyl Database & .env Backup
```bash
# root reccomended
curl -SsL g.oaka.xyz/scripts/ptero/backup_panel.sh | bash -s -- '<custom backup location>'
```

### Pterodactyl Updater (untested)

Update your panel, even if its all the way back in 0.6!
```bash
# root required
curl -SsL g.oaka.xyz/scripts/ptero/update.sh | bash -s -- -a
```

### Pterodactyl Yeeter (untested)

Uninstall Pterodactyl Panel and/or Wings easily!
```bash
# root required
curl -SsL g.oaka.xyz/scripts/ptero/uninstall.sh | bash -s --
```

### Pterodactyl Database Migrator (not made)

Transfer your panel database elsewhere
```bash
# root required
curl -SsL g.oaka.xyz/scripts/ptero/migrate_db.sh | bash -s --
```

## Minecraft Scripts

### Dynmap Proxy Creation Tool for Nginx or Apache (untested)
```bash
# root required
curl -SsL g.oaka.xyz/scripts/mc/dynmap_proxy.sh | bash
```
