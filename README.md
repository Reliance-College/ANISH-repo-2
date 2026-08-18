#  Final Capstone — Remote Server Monitoring & Maintenance Suite

This is the **grand finale** of the course. It combines everything from Part 1 (the Bash
language) and Part 2 (system administration & networking) into a single production-grade tool
that monitors a fleet of servers and performs routine maintenance — the kind of script a real
DevOps/SRE team runs from cron.

If you can build, read, and extend this, you are **project-grade**.

---

## What it does

- **Monitors a fleet** of hosts defined in a config file — each host is either `local` or a
  remote SSH target.
- **Runs health checks** on each host (locally or over SSH): disk usage, memory, load average,
  and systemd service status — graded against configurable thresholds.
- **Checks the network**: reachability (ping), and HTTP/HTTPS endpoint status codes.
- **Alerts on changes** via a webhook (Slack/Discord/Teams) — only when a host transitions
  between healthy and unhealthy (no alert fatigue).
- **Takes backups** of configured paths as timestamped archives, with retention/pruning.
- **Rotates its own logs** by size.
- **Runs from cron** safely with single-instance `flock` locking, and exits with a status code
  that reflects severity (0 OK / 1 WARN / 2 CRIT).

---

## File layout

```
final-project-ops/
├── README.md                ← you are here
├── monitor.sh               ← main entry: option/command parsing, dispatch, menu, locking
├── config/
│   ├── monitor.conf         ← thresholds, webhook, backup & log settings (KEY=VALUE)
│   └── hosts.conf           ← the fleet: name | target | services | endpoints
└── lib/
    ├── common.sh            ← config loader, logging, notify, run_on, retry, port/http checks
    ├── checks.sh            ← disk / memory / load / services / reachability / HTTP checks
    ├── report.sh            ← per-host orchestration, report, change-based alerting
    └── maintenance.sh       ← backups (with retention) + self log rotation
```

This is the **`main` + sourced library modules** structure from Lesson 25/37, scaled up.

---

## Quick start (runs out of the box)

The default `hosts.conf` monitors only the **local** machine, so no SSH setup is needed:

```bash
cd final-project-ops
chmod +x monitor.sh lib/*.sh

./monitor.sh                 # run a monitoring pass (default command = check)
./monitor.sh backup          # back up the configured paths
./monitor.sh maintain        # backup + rotate logs
./monitor.sh menu            # interactive menu
./monitor.sh install-cron    # print ready-to-paste crontab lines
./monitor.sh -h              # help
```

Example output of a pass:

```
── Host: local (local) ──
  [OK  ] host is local
  [OK  ] disk OK (busiest: 29 /)
  [OK  ] memory OK (35% used)
  [OK  ] load OK (0.41 on 8 cores)
  [OK  ] service cron active
  [OK  ] HTTP https://example.com -> 200
  => local status: OK
Summary: 1 host(s), 0 with problems, overall OK
```

---

## Configuring it

### `config/hosts.conf` — the fleet

```
# name | target | services | endpoints
local | local | cron,systemd-journald | https://example.com
web1  | deploy@web1.example.com | nginx,sshd | https://web1.example.com/health
db1   | admin@10.0.0.5 | postgresql,sshd | -
```

- `target` is `local` (this machine) or any SSH target (`user@host`). Remote hosts use your
  `~/.ssh/config`, keys, and `BatchMode` (Lesson 31) — set up key auth first.
- `services` and `endpoints` are comma-separated (or `-` for none).

### `config/monitor.conf` — thresholds & behavior

Edit thresholds (`DISK_WARN_PCT`, `MEM_WARN_PCT`, `LOAD_WARN_PER_CORE`), set a `WEBHOOK_URL`
to enable real alerts, and configure `BACKUP_TARGETS`/`BACKUP_DIR`/`BACKUP_KEEP`. **Any setting
can be overridden by an environment variable of the same name** (Lesson 28), e.g.:

```bash
DISK_WARN_PCT=70 WEBHOOK_URL=https://hooks.slack.com/... ./monitor.sh check
```

---

## Running it on a schedule (production)

```bash
./monitor.sh install-cron      # prints these lines for you:
# */5 * * * * /usr/bin/flock -n /tmp/ops-monitor.lock /path/monitor.sh check >> /tmp/ops-monitor/cron.log 2>&1
# 30 2 * * *  /usr/bin/flock -n /tmp/ops-maintain.lock /path/monitor.sh maintain >> /tmp/ops-monitor/cron.log 2>&1
```

`flock` guarantees runs never overlap (Lesson 32); the absolute paths survive cron's minimal
environment.

---

## Concept → code map (the whole course, applied)

| Concept (lesson) | Where it lives |
|------------------|----------------|
| Structure, `main "$@"`, comments (L1–2, 25) | `monitor.sh` |
| Variables, quoting, params (L3, 5, 18) | everywhere; `cfg()` defaults |
| Conditionals & `case` (L8, 10) | command dispatch, severity grading |
| Loops & `select` (L11–13) | host loop, threshold loops, the menu |
| Arrays (L14) | `FINDINGS`, service/endpoint lists, host fields |
| Functions & scope (L15–16) | every `lib/` function is `local`-scoped |
| Redirection & here-docs (L19) | logging to file+stderr, `usage()`/`install_cron` |
| Errors, exit codes, traps (L20, 37) | per-check error handling; severity exit codes |
| `getopts` (L21) | `monitor.sh` option parsing |
| Files & retention (L22, 35) | backups, pruning |
| Text processing (L23) | parsing `df`/`free`/`/proc/loadavg` with awk |
| Permissions (L26) | secret-safe config, log dirs |
| Config files (L28) | `load_config` + `cfg` with env overrides |
| Networking (L29) | `ping`, pure-bash `check_port`, reachability |
| HTTP/JSON/webhooks (L30) | `http_status`, `notify` via `jq -n`+`curl` |
| SSH & `run_on` (L31) | local/remote command execution |
| Cron & `flock` (L32) | `acquire_lock`, `install_cron` |
| Log rotation (L33) | `rotate_logs` |
| Services/systemd (L34) | `check_services` via `systemctl is-active` |
| Backups & retention (L35) | `do_backup`, `_prune_backups` |
| Security (L36) | secrets in env/config, never in argv |
| Production patterns (L37) | logging, retry, dry-run, idempotency, locking |

---

## Build-it-yourself guide (stages)

1. **Skeleton + config**: `monitor.sh` with strict mode, `getopts`, `usage`, and a `cfg`
   loader reading `monitor.conf`. (L21, 28, 37)
2. **Common lib**: logging, `die`, `run_on` (local/remote), `notify`. Test `run_on local`. (L31)
3. **Checks**: implement `check_disk/mem/load/services` parsing command output with awk; grade
   against thresholds via `note()`. (L23, 34)
4. **Network checks**: `check_reachable` (ping + ssh true), `check_endpoints` (HTTP). (L29, 30)
5. **Orchestration**: parse `hosts.conf`, loop hosts, print per-host blocks and a summary,
   return a severity exit code. (L12, 14)
6. **Alerting**: persist a state file; notify only on OK↔problem transitions. (L30, 37)
7. **Maintenance**: `do_backup` with retention and `rotate_logs`. (L35, 33)
8. **Production hardening**: `flock` single-instance, dry-run, `install-cron`, and a `select`
   menu. (L13, 32)

---

## Grading rubric (100 pts)

| Criteria | Points |
|----------|-------:|
| Clean run; `bash -n` clean; `shellcheck` addressed; modular `lib/` | 10 |
| Config-driven (hosts + settings), with env overrides | 12 |
| `run_on` local/remote abstraction over SSH | 12 |
| Health checks (disk/mem/load/services) with thresholds | 16 |
| Network checks (reachability + HTTP status) | 12 |
| Change-based alerting via webhook (`notify`) | 10 |
| Backups with retention + self log rotation | 12 |
| Cron-safe: `flock` locking, absolute paths, severity exit codes | 10 |
| Robustness: graceful handling of down/unreachable hosts; logging | 6 |
| **Total** | **100** |

**Stretch goals:** parallelize host checks with background jobs + `wait` (L24); add a
`--json` report mode (jq); add `retry` around flaky endpoints; pull remote logs with `rsync`
and analyze them; write a `systemd` timer unit instead of cron (L34); add a `restore` command
for backups.

---

## Try the alerting & failure paths

```bash
# Force a warning by tightening a threshold (alerts on the state change):
DISK_WARN_PCT=10 ./monitor.sh check

# Point at a host file with an unreachable remote to see graceful degradation:
printf 'local|local|cron|-\nbad|nouser@10.255.255.1|nginx|-\n' > /tmp/h.conf
./monitor.sh -H /tmp/h.conf check      # 'bad' -> CRIT, local stays OK, exit 2
```
