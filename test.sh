#!/usr/bin/env bash
set -u

SERVER="./server"
CLIENT="./client"

PASS=0
FAIL=0

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

  # attendre que le serveur écrive le PID
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

run_valid() {
  local label="$1"
  local msg="$2"

  local out client_out srv proc_pid target_pid actual expected rc
  out="$(mktemp)"
  client_out="$(mktemp)"

  srv="$(start_server "$out")" || { echo "❌ $label (server start)"; ((FAIL++)); rm -f "$out" "$client_out"; return; }
  proc_pid="$(awk '{print $1}' <<<"$srv")"
  target_pid="$(awk '{print $2}' <<<"$srv")"

  "$CLIENT" "$target_pid" "$msg" >"$client_out" 2>&1
  rc=$?

  sleep 0.25
  cleanup_server "$proc_pid"

  actual="$(server_output_no_pid "$out")"
  expected="${msg}"$'\n'

  if [[ "$actual" == "$expected" || "$actual" == "$msg" ]]; then
    echo "✅ $label"
    ((PASS++))
  else
    echo "❌ $label"
    echo "   attendu: $(printf "%q" "$expected") (ou sans \\n)"
    echo "   reçu   : $(printf "%q" "$actual")"
    echo "   rc client: $rc"
    echo "   sortie client: $(tr '\n' ' ' < "$client_out")"
    ((FAIL++))
  fi

  rm -f "$out" "$client_out"
}

run_invalid_usage() {
  local label="$1"; shift
  local out rc
  out="$(mktemp)"
  "$CLIENT" "$@" >"$out" 2>&1 || rc=$?
  rc=${rc:-0}
  if grep -q "Usage:" "$out"; then
    echo "✅ $label"
    ((PASS++))
  else
    echo "❌ $label"
    cat "$out"
    ((FAIL++))
  fi
  rm -f "$out"
}

run_invalid_no_server_print() {
  local label="$1"
  local pid_arg="$2"
  local msg="$3"

  local out srv proc_pid target_pid actual
  out="$(mktemp)"

  srv="$(start_server "$out")" || { echo "❌ $label (server start)"; ((FAIL++)); rm -f "$out"; return; }
  proc_pid="$(awk '{print $1}' <<<"$srv")"
  target_pid="$(awk '{print $2}' <<<"$srv")"

  if [[ "$pid_arg" == "__PID__" ]]; then
    pid_arg="$target_pid"
  fi

  "$CLIENT" "$pid_arg" "$msg" >/dev/null 2>&1 || true
  sleep 0.25
  cleanup_server "$proc_pid"

  actual="$(server_output_no_pid "$out")"
  if [[ -z "$actual" ]]; then
    echo "✅ $label"
    ((PASS++))
  else
    echo "❌ $label (le serveur a écrit: $(printf "%q" "$actual"))"
    ((FAIL++))
  fi

  rm -f "$out"
}

echo "=== make re ==="
make re >/dev/null

echo "=== VALIDES ==="
run_valid "Msg simple" "bonjour"
run_valid "Majuscules" "BONjour"
run_valid "Espaces" "hello world"
run_valid "Vide" ""

echo "=== INVALIDES (usage) ==="
run_invalid_usage "Aucun argument"
run_invalid_usage "1 argument" "123"
run_invalid_usage "4 arguments" "123" "hi" "extra"

echo "=== INVALIDES (serveur ne doit rien imprimer) ==="
run_invalid_no_server_print "PID 0" "0" "hi"
run_invalid_no_server_print "PID negatif" "-1" "hi"
run_invalid_no_server_print "PID inexistant" "999999" "hi"
run_invalid_no_server_print "PID valide mais manque message" "__PID__" ""  # ici on ne lance pas vraiment client (argc!=3) donc pas de print attendu

echo "=== Résultat ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
exit $FAIL
