#!/usr/bin/env bash
set -euo pipefail

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

  # attendre que le serveur écrive son PID (ligne 1)
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

server_body() {
  # Tout sauf la première ligne (PID)
  tail -n +2 "$1" 2>/dev/null || true
}

# Attend la fin de message: le serveur imprime \n quand il reçoit '\0'
wait_server_newline() {
  local out="$1"
  local timeout_ms="${2:-2000}"
  local waited=0

  while (( waited < timeout_ms )); do
    # si on trouve au moins un \n dans le body, on considère "message terminé"
    if server_body "$out" | grep -q $'\n'; then
      return 0
    fi
    sleep 0.01
    waited=$((waited + 10))
  done
  return 1
}

ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ko() { echo "❌ $1"; FAIL=$((FAIL+1)); }

expect_usage() {
  local label="$1"; shift
  local tmp
  tmp="$(mktemp)"
  set +e
  "$CLIENT" "$@" >"$tmp" 2>&1
  local rc=$?
  set -e
  if grep -q "Usage:" "$tmp"; then
    ok "$label"
  else
    ko "$label (pas de Usage:)"
    echo "   rc=$rc, sortie:"
    sed -n '1,5p' "$tmp"
  fi
  rm -f "$tmp"
}

expect_client_fail_silent() {
  # Le client doit échouer (rc != 0) et ne rien imprimer (ou presque)
  local label="$1"; shift
  local tmp
  tmp="$(mktemp)"
  set +e
  "$CLIENT" "$@" >"$tmp" 2>&1
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    # accepte sortie vide ou très courte
    if [[ ! -s "$tmp" ]]; then
      ok "$label"
    else
      # si tu préfères stricte: considère KO
      ok "$label (rc!=0 mais sortie non vide acceptée)"
    fi
  else
    ko "$label (rc=0 attendu !=0)"
    echo "   sortie:"
    sed -n '1,5p' "$tmp"
  fi
  rm -f "$tmp"
}

expect_server_no_print() {
  local label="$1"
  local pid_arg="$2"
  local msg="$3"

  local out srv proc_pid target_pid body
  out="$(mktemp)"

  srv="$(start_server "$out")" || { ko "$label (server start)"; rm -f "$out"; return; }
  proc_pid="$(awk '{print $1}' <<<"$srv")"
  target_pid="$(awk '{print $2}' <<<"$srv")"

  if [[ "$pid_arg" == "__PID__" ]]; then
    pid_arg="$target_pid"
  fi

  set +e
  "$CLIENT" "$pid_arg" "$msg" >/dev/null 2>&1
  set -e

  # attendre un peu
  sleep 0.2
  body="$(server_body "$out")"
  cleanup_server "$proc_pid"
  rm -f "$out"

  if [[ -z "$body" ]]; then
    ok "$label"
  else
    ko "$label (le serveur a imprimé quelque chose)"
    printf "   body=%q\n" "$body"
  fi
}

expect_server_msg() {
  local label="$1"
  local msg="$2"

  local out srv proc_pid target_pid body
  out="$(mktemp)"

  srv="$(start_server "$out")" || { ko "$label (server start)"; rm -f "$out"; return; }
  proc_pid="$(awk '{print $1}' <<<"$srv")"
  target_pid="$(awk '{print $2}' <<<"$srv")"

  set +e
  "$CLIENT" "$target_pid" "$msg" >/dev/null 2>&1
  local rc=$?
  set -e

  # attendre fin message (newline)
  if ! wait_server_newline "$out" 3000; then
    ko "$label (timeout fin message)"
    cleanup_server "$proc_pid"
    rm -f "$out"
    return
  fi

  body="$(server_body "$out")"
  cleanup_server "$proc_pid"
  rm -f "$out"

  # Le serveur ajoute un '\n' à la fin
  if [[ "$body" == "$msg"$'\n' || "$body" == "$msg" ]]; then
    ok "$label"
  else
    ko "$label"
    printf "   attendu=%q (ou sans \\n)\n" "$msg"$'\n'
    printf "   reçu   =%q\n" "$body"
    echo "   rc client=$rc"
  fi
}

expect_two_clients_sequential() {
  local label="$1"
  local msg1="$2"
  local msg2="$3"

  local out srv proc_pid target_pid expected
  local actualf expectedf
  out="$(mktemp)"
  actualf="$(mktemp)"
  expectedf="$(mktemp)"

  srv="$(start_server "$out")" || { ko "$label (server start)"; rm -f "$out" "$actualf" "$expectedf"; return; }
  proc_pid="$(awk '{print $1}' <<<"$srv")"
  target_pid="$(awk '{print $2}' <<<"$srv")"

  "$CLIENT" "$target_pid" "$msg1" >/dev/null 2>&1 || true
  "$CLIENT" "$target_pid" "$msg2" >/dev/null 2>&1 || true

  expected="${msg1}"$'\n'"${msg2}"$'\n'
  printf "%s" "$expected" > "$expectedf"

  # Attendre que le fichier contienne exactement expected
  local timeout_ms=4000
  local waited=0
  while (( waited < timeout_ms )); do
    tail -n +2 "$out" > "$actualf"
    if cmp -s "$actualf" "$expectedf"; then
      break
    fi
    sleep 0.01
    waited=$((waited + 10))
  done

  tail -n +2 "$out" > "$actualf"
  cleanup_server "$proc_pid"
  rm -f "$out"

  if cmp -s "$actualf" "$expectedf"; then
    ok "$label"
  else
    ko "$label"
    echo "   attendu (repr): $(printf "%q" "$expected")"
    echo "   reçu    (repr): $(printf "%q" "$(cat "$actualf")")"
  fi

  rm -f "$actualf" "$expectedf"
}


echo "=== make re ==="
make re >/dev/null

echo
echo "=== ARGUMENTS / USAGE ==="
expect_usage "Aucun argument" || true
expect_usage "1 argument" "123" || true
expect_usage "4 arguments" "123" "hi" "extra" || true

echo
echo "=== PID farfelus (client doit refuser) ==="
expect_client_fail_silent "PID vide (argc=3 mais pid='')" "" "hi" || true
expect_client_fail_silent "PID non numérique 'abc'" "abc" "hi" || true
expect_client_fail_silent "PID mix '12a3'" "12a3" "hi" || true
expect_client_fail_silent "PID espace ' 42' (avec espaces)" " 42" "hi" || true
expect_client_fail_silent "PID '+42'" "+42" "hi" || true
expect_client_fail_silent "PID '-1'" "-1" "hi" || true
expect_client_fail_silent "PID '0'" "0" "hi" || true
expect_client_fail_silent "PID huge '999999999999'" "999999999999" "hi" || true

echo
echo "=== PID inexistant (serveur ne doit rien imprimer) ==="
expect_server_no_print "PID inexistant 999999" "999999" "hi" || true
expect_server_no_print "PID inexistant 424242" "424242" "hello" || true

echo
echo "=== Messages farfelus (doivent passer) ==="
expect_server_msg "Message vide" "" || true
expect_server_msg "Espaces" "     " || true
expect_server_msg "Tabs" $'\t\t\t' || true
expect_server_msg "Ponctuation" "!@#\$%^&*()_+-=[]{};':,./<>?" || true
expect_server_msg "UTF-8 simple" "éàçø" || true

echo
echo "=== Messages avec shell tricky ==="
expect_server_msg "Guillemets simples" "c'est ok" || true
expect_server_msg "Guillemets doubles" 'il dit "ok"' || true
expect_server_msg "Backslash" 'a\b\c\\d' || true

echo
echo "=== Enchaînement de clients (même serveur, 2 messages) ==="
expect_two_clients_sequential "Deux messages à la suite" "first" "second" || true
expect_two_clients_sequential "Deux messages (vides/espaces)" "" "   " || true

echo
echo "=== Résultat ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
exit $FAIL
