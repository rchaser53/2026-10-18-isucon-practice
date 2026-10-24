#!/usr/bin/env bash
# Linux/Bash用。指定されたコマンドを現在のディレクトリで実行する。
set -euo pipefail
if [[ ${1:-} != -- || $# -lt 2 ]]; then
  echo "Usage: bash scripts/benchmark.sh -- command [args...]" >&2
  exit 2
fi
shift
command -v flock >/dev/null || { echo "flock (util-linux) is required" >&2; exit 2; }
umask 077
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
result_root=${RESULTS_DIR:-"$script_dir/../results"}
mkdir -p -- "$result_root"
result_root=$(cd -- "$result_root" && pwd)
# 同じ結果ディレクトリを使う実行間のみ排他。ロックファイルは削除しない。
exec 9>"$result_root/.benchmark.lock"
flock -n 9 || { echo "Another benchmark is running: $result_root" >&2; exit 75; }
run_dir=$(mktemp -d "$result_root/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
printf 'Results: %s\n' "$run_dir"
{
  printf 'started_at_utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'host=%s\n' "$(hostname)"
  printf 'cwd=%s\n' "$PWD"
  printf 'command='; printf '%q ' "$@"; printf '\n'
  printf 'git_commit='; git rev-parse HEAD 2>/dev/null || true
  git status --short 2>/dev/null || true
} > "$run_dir/metadata.txt"
snapshot() {
  { date -u +%FT%TZ; uptime; free -h; df -h; } > "$1" 2>&1 || true
}
snapshot "$run_dir/before.txt"
start=$SECONDS
set +e
"$@" 9>&- > "$run_dir/stdout.log" 2> "$run_dir/stderr.log"
status=$?
set -e
elapsed=$((SECONDS - start))
snapshot "$run_dir/after.txt"
printf 'exit_code=%s\nelapsed_seconds=%s\nfinished_at_utc=%s\n' \
  "$status" "$elapsed" "$(date -u +%FT%TZ)" > "$run_dir/result.txt"
cat "$run_dir/result.txt"
exit "$status"
