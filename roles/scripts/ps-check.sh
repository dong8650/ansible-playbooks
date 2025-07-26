#!/bin/bash

echo "📦 전체 시스템 포트/프로세스 진단 시작"
echo "HOSTNAME: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo

tmpfile=$(mktemp)

ss -tulpenH | awk '
{
  proto = $1
  local = $5
  users = $7

  split(local, a, ":")
  port = a[length(a)]

  if (users !~ /^users:\(\(.+\)\)$/) next

  gsub(/^users:\(\(/, "", users)
  gsub(/\)\)$/, "", users)

  split(users, pairs, "\\),\\(")

  for (i in pairs) {
    entry = pairs[i]
    split(entry, fields, ",")
    pid = ""; proc = ""
    for (j in fields) {
      if (fields[j] ~ /^pid=/) {
        gsub("pid=", "", fields[j])
        pid = fields[j]
      } else if (fields[j] !~ /fd=/) {
        proc = fields[j]
      }
    }
    if (pid != "" && proc != "") {
      key = port "|" proto
      pid_map[key][pid] = 1
      proc_map[key][proc] = 1
    }
  }
}
END {
  for (key in pid_map) {
    split(key, parts, "|")
    port = parts[1]
    proto = parts[2]

    pids = ""; procs = ""
    for (pid in pid_map[key]) {
      pids = (pids == "") ? pid : pids "," pid
    }
    for (proc in proc_map[key]) {
      procs = (procs == "") ? proc : procs "," proc
    }

    gsub(/"/, "", procs)

    print port "|" proto "|" pids "|" procs
  }
}' | sort -n > "$tmpfile"

printf "%-8s %-6s %-13s %-29s %-s\n" "PORT" "PROTO" "PID(s)" "PROCESS(es)" "SERVICE"
printf "%-8s %-6s %-13s %-29s %-s\n" "--------" "------" "-------------" "-----------------------------" "----------------"

awk -F'|' '
{
  port = $1
  proto = $2
  pids = $3
  procs = $4

  svc = "(unknown)"
  cmd = "getent services " port "/" proto
  if (cmd | getline line) {
    split(line, a, " ")
    svc = a[1]
  }
  close(cmd)

  printf "%-8s %-6s %-13s %-29s %-s\n", port, proto, pids, procs, svc
}
' "$tmpfile"

rm -f "$tmpfile"

