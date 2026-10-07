# Disk Reclaim

Free space on `/` in the bar, and one panel that lists what you can clean on
an Arch/Omarchy box, biggest first, each with its size and a Clean button.

Freeing space on Arch means remembering a dozen commands: `paccache`,
`yay -Sc`, `journalctl --vacuum-size`, `pacman -Rns $(pacman -Qdtq)`, emptying
the trash, `docker system prune`. This puts them in one place and shows what
each one would get back before you run it.

## Install

```bash
omarchy plugin add https://github.com/Nejcc/omarchy-disk-reclaim.git
omarchy plugin enable nejcc.disk-reclaim
```

## Uninstall

```sh
omarchy plugin remove nejcc.disk-reclaim
```

Nothing is left behind.

## Usage

The bar shows a disk icon and the free space on `/`. Under 10% free it turns
the urgent color (change it with `warnPercent` in the widget settings).

Click it to open the panel. It scans when it opens:

| Category | Shown as | Clean runs |
|---|---|---|
| Pacman cache | what `paccache -dk2` would free | `sudo paccache -rk2` (lists the files first, asks) |
| Orphan packages | installed size of `pacman -Qdtq` | `sudo pacman -Rns …` (pacman asks) |
| Yay / Paru build cache | size of `~/.cache/yay`, `~/.cache/paru` | `yay -Sc --aur` / `paru -Sc --aur` (they ask) |
| Systemd journal | journal size above 100M | `sudo journalctl --vacuum-size=100M` (asks) |
| Trash | size of `~/.local/share/Trash` | empties it (asks) |
| User cache | files in `~/.cache` untouched for 30 days | deletes those files (shows the biggest folders, asks) |
| Docker | reclaimable from `docker system df`, without volumes | `docker system prune -a` (Docker asks) |
| Snapper snapshots | count only | nothing, manage them with snapper or Limine |

Clean opens a floating Omarchy terminal. It shows the preview, then the exact
command, and asks before anything is removed; sudo prompts happen there too,
where you can see them. Nothing is ever passed `--noconfirm`. When the
terminal closes the panel scans again.

## Runtime dependencies

`pacman`, `du`, `df`, `find`, `timeout` (all on Omarchy). Optional:
`pacman-contrib` (exact pacman cache figure via `paccache`), `yay` or `paru`,
`docker`, `snapper`. Missing tools just hide their row.

## How it works

`bin/disk-reclaim scan --json` runs read-only probes as your user, each with a
timeout and at idle I/O priority, and prints one JSON row per category. The
bar widget runs `df` on `/` every five minutes and does nothing else while the
panel is closed. `bin/disk-reclaim launch <id>` opens
`omarchy-launch-floating-terminal-with-presentation` with
`disk-reclaim clean <id>` and waits until that terminal is done.

## Limits

- Docker shows up only when the daemon answers without sudo (you are in the
  `docker` group). Snapper shows up only when your user may list snapshots
  (`ALLOW_USERS` in the snapper config).
- `journalctl --disk-usage` counts the journals your user can read.
- A folder that takes longer than 8 seconds to measure shows as 0. Set
  `DISK_RECLAIM_TIMEOUT` to change it.
- Only the trash in your home folder is counted, not trash on other drives.

## Tests

```bash
bash tests/parse.test.sh
node --test tests/*.test.mjs
```

## License

MIT
