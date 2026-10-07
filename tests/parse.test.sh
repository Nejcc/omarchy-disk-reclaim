#!/usr/bin/env bash
# shellcheck disable=SC2016 # stub bodies expand inside the stubs, not here
# Parsers in bin/disk-reclaim against captured command output, plus a scan
# with stub commands on PATH so the JSON shape is checked without touching
# the real system.
#
#   bash tests/parse.test.sh
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=bin/disk-reclaim
source "$HERE/bin/disk-reclaim"

fail=0
eq() {
  if [[ $2 == "$3" ]]; then
    echo "PASS  $1"
  else
    echo "FAIL  $1: expected '$3', got '$2'"
    fail=1
  fi
}

eq "bytes B" "$(to_bytes "0B")" 0
eq "bytes KiB" "$(to_bytes "345.21 KiB")" 353495
eq "bytes journal M" "$(to_bytes "32M")" 33554432
eq "bytes docker GB is decimal" "$(to_bytes "1.2GB")" 1200000000
eq "bytes docker kB" "$(to_bytes "512kB")" 512000
eq "bytes junk" "$(to_bytes "n/a")" 0

eq "paccache saved" "$(
  parse_paccache <<'EOF'
==> finished dry run: 12 candidates (disk space saved: 1.50 GiB)
EOF
)" 1610612736

eq "paccache nothing" "$(
  parse_paccache <<'EOF'
==> no candidate packages found for pruning
EOF
)" 0

eq "journal" "$(
  parse_journal <<'EOF'
Archived and active journals take up 1.2G in the file system.
EOF
)" 1288490189

eq "pacman installed sum" "$(
  parse_pacman_installed <<'EOF'
Name            : foo
Installed Size  : 6.00 MiB
Packager        : Someone
Name            : bar
Installed Size  : 512.00 KiB
Name            : baz
Installed Size  : 0.00 B
EOF
)" 6815744

eq "docker without volumes" "$(
  parse_docker <<'EOF'
Images	2.5GB (80%)
Containers	10MB (100%)
Local Volumes	4GB (100%)
Build Cache	500MB
EOF
)" 3010000000

eq "snapper skips 0" "$(
  parse_snapper <<'EOF'
root,0
root,1
root,2
home,0
home,5
EOF
)" 3

eq "du empty" "$(parse_du </dev/null)" 0
eq "du" "$(parse_du <<<"1234	/x")" 1234

# ---- scan with stubs ----
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
mk() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$stub/bin/$1"
  chmod +x "$stub/bin/$1"
}
mkdir -p "$stub/bin" "$stub/home/.cache/yay" "$stub/home/.local/share/Trash/files" "$stub/pkg"
head -c 4096 /dev/zero >"$stub/home/.cache/yay/a"
head -c 2048 /dev/zero >"$stub/home/.local/share/Trash/files/b"
mk pacman 'case "$1" in -Qdtq) printf "foo\nbar\n" ;; -Qi) printf "Installed Size  : 1.00 MiB\nInstalled Size  : 1.00 MiB\n" ;; esac'
mk pacman-conf "echo $stub/pkg"
mk paccache 'echo "==> finished dry run: 1 candidates (disk space saved: 3.00 MiB)"'
mk journalctl 'echo "Archived and active journals take up 300M in the file system."'
mk docker 'case "$1" in info) exit 1 ;; esac'
mk snapper 'echo "No permissions."; exit 1'

json=$(HOME=$stub/home XDG_CACHE_HOME="" XDG_DATA_HOME="" PATH="$stub/bin:$PATH" bash "$HERE/bin/disk-reclaim" scan --json)
if command -v node >/dev/null; then
  got=$(node -e '
    const c = JSON.parse(process.argv[1]); const by = Object.fromEntries(c.map(x => [x.id, x]))
    console.log([c.map(x => x.id).join(","), by.pacman.reclaim, by.orphans.reclaim, by.orphans.detail,
      by.journal.reclaim, by.trash.reclaim >= 2048, by.yay.reclaim >= 4096].join(" "))' "$json")
  eq "scan json" "$got" "pacman,orphans,yay,journal,trash,cache 3145728 2097152 2 packages 209715200 true true"
else
  echo "SKIP  scan json (node not found)"
fi

exit $fail
