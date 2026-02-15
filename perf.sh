#!/usr/bin/env bash
set -euo pipefail

SERVER="./server"
CLIENT="./client"

cleanup_server() {
  local spid="${1:-}"
  if [[ -n "$spid" ]] && kill -0 "$spid" 2>/dev/null; then
    kill -TERM "$spid" 2>/dev/null || true
    sleep 0.05
    kill -KILL "$spid" 2>/dev/null || true
  fi
}

start_server() {
  local out="$1"
  : > "$out"
  "$SERVER" >"$out" 2>&1 &
  local proc_pid=$!

  for _ in {1..200}; do
    [[ -s "$out" ]] && break
    sleep 0.01
  done

  local target_pid
  target_pid="$(head -n 1 "$out" | tr -d '\r\n' || true)"
  if [[ ! "$target_pid" =~ ^[0-9]+$ ]]; then
    echo "ERR: PID serveur illisible"
    cat "$out"
    cleanup_server "$proc_pid"
    return 1
  fi

  echo "$proc_pid $target_pid"
}

server_output_no_pid() {
  tail -n +2 "$1" 2>/dev/null || true
}

# Génère une chaîne de longueur N (caractère 'a')
gen_msg() {
  local n="$1"
  python3 - <<PY
n=int("$n")
print("a"*n, end="")
PY
}

echo "=== make re ==="
make re >/dev/null

OUT="$(mktemp)"
trap 'cleanup_server "${SERVER_PROC_PID:-}"; rm -f "$OUT"' EXIT

srv="$(start_server "$OUT")"
SERVER_PROC_PID="$(awk '{print $1}' <<<"$srv")"
SERVER_TARGET_PID="$(awk '{print $2}' <<<"$srv")"

echo "PID serveur: $SERVER_TARGET_PID"
echo
printf "%-10s %-12s %-12s %-8s\n" "len" "time_ms" "chars/s" "check"
echo "------------------------------------------------------"

# tailles testées
SIZES=(10 50 100 200 500 1000 2000)

for n in "${SIZES[@]}"; do
  : > "$OUT"
  # relance serveur pour chaque test pour éviter accumulation sortie
  cleanup_server "$SERVER_PROC_PID"
  srv="$(start_server "$OUT")"
  SERVER_PROC_PID="$(awk '{print $1}' <<<"$srv")"
  SERVER_TARGET_PID="$(awk '{print $2}' <<<"$srv")"

  MSG="$(gen_msg "$n")"

  start_ns="$(date +%s%N)"
  "$CLIENT" "$SERVER_TARGET_PID" "$MSG" >/dev/null 2>&1 || true
  end_ns="$(date +%s%N)"

  # Laisser le serveur écrire
  sleep 0.3
  cleanup_server "$SERVER_PROC_PID"

  elapsed_ns=$((end_ns - start_ns))
  elapsed_ms=$((elapsed_ns / 1000000))
  if [[ "$elapsed_ms" -le 0 ]]; then elapsed_ms=1; fi

  # Vérif réception : on accepte avec ou sans \n final
  actual="$(server_output_no_pid "$OUT")"
  ok="KO"
  if [[ "$actual" == "$MSG" || "$actual" == "${MSG}"$'\n' ]]; then
    ok="OK"
  fi

  # débit approx
  cps=$(( n * 1000 / elapsed_ms ))

  printf "%-10s %-12s %-12s %-8s\n" "$n" "$elapsed_ms" "$cps" "$ok"
done
