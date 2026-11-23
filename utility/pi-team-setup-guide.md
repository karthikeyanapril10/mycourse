# pi Setup Guide — Team Onboarding (Windows)

Step-by-step setup for a Billtrust dev machine, from zero to a working pi session with
OpenRouter models (including the `:free` ones), team skills, and MCP servers.

Everything below was executed/verified on Windows on 2026-11-12 unless marked
**[doc]** (taken from the pi docs, not re-run here).

---

## 0. Prerequisites

| Tool | Why | Check |
|---|---|---|
| Node.js ≥ 22.19 | npm install path | `node -v` |
| Git for Windows | pi uses Git Bash for its `bash` tool | `bash --version` |
| `gh` CLI (authenticated) | GitHub MCP + PR work | `gh auth status` |
| Docker Desktop | GitHub MCP container, MySQL gateway, PHP lint | `docker info` |
| VS Code + pi extension (optional) | IDE bridge tools | — |

**[doc]** pi runs on native Windows using Git Bash by default; if Bash is not found it
prints the locations it checked. Setting `"shellPath"` in `settings.json` overrides discovery.

---

## 1. Install pi

PowerShell (recommended — pins dependencies, updates via `pi update`):

```powershell
powershell -c "irm https://pi.dev/install.ps1 | iex"
```

Or via npm (**[doc]** requires Node ≥ 22.19):

```powershell
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

Verify:

```powershell
pi --version
```

---

## 2. Start pi in a repo folder

```powershell
cd C:\Users\<you>\GH\<repo>
pi
```

First launch in a new folder asks you to trust the project. Trust only repos you own/work in.

---

## 3. Authenticate a provider (OpenRouter)

Inside pi:

```text
/login openrouter
```

Paste your OpenRouter API key. Credentials land in `~/.pi/agent/auth.json`.
Non-interactive alternative (**[doc]**): set `OPENROUTER_API_KEY` before launching pi.

Other providers: `/login anthropic`, `/login github-copilot`, … or `/login` with no argument
to pick from a list. Check the credential took effect:

```text
/model
```

---

## 4. Configure pi's defaults and model scope

Edit `~/.pi/agent/settings.json` (interactive equivalent: `/settings`):

```json
{
  "defaultProvider": "openrouter",
  "defaultModel": "deepseek/deepseek-v4.1-flash-1017",
  "defaultThinkingLevel": "high",
  "enabledModels": [
    "anthropic/claude-opus-5.5",
    "z-ai/glm-5.3",
    "z-ai/glm-5.3-flash",
    "deepseek/deepseek-v4.1-flash-1017"
  ]
}
```

- `enabledModels` = the models you can start with and cycle through with `Ctrl+P`.
  Same format as `--models`: exact IDs, fuzzy matches, case-insensitive globs, optional
  `:thinking` suffix. **Prefer exact IDs** and treat pi's per-pattern warning as the check
  (see below), because a typo gives no error inside the picker.
- Note (verified): `pi --list-models` lists **all available chat models**, not just
  `enabledModels` — so don't use it to confirm your scope. The scope shows up in `/model`
  and in `Ctrl+P` cycling inside a session.
- Save a model/thinking level as the default from the picker: `Ctrl+S` in `/model` and `/thinking`.
- `/reload` after hand-editing any config file.

**Sanity check for dead entries** — every `pi --list-models` prints a warning per pattern
that matches nothing:

```powershell
pi --list-models
# Warning: No models match pattern "x-ai/grok-4.6"
```

Remove or fix those IDs; a stale entry is silent in the picker but noisy on every CLI call.

---

## 5. Refresh the model catalog (fixes "the model isn't in `/model`")

**Symptom:** a model exists on OpenRouter's site but pi never shows it, and
`pi --list-models free` says `No models matching "free"`.

**Cause (verified):** pi reads `~/.pi/agent/models-store.json`. A stale/pruned cache silently
limits the picker. Measured today on the same key:

| Agent dir | catalog source | chat models | `:free` models |
|---|---|---|---|
| real `~/.pi/agent` (cached) | `models-store.json` | 12 | 0 |
| fresh agent dir (live fetch) | OpenRouter `/models/user` | 389 | 13 |

**Fix:**

```powershell
pi update --models
```

pi also refreshes in the background at startup, when `/model` opens, after `/login`, and on
`pi update --models`. The last successful list is kept for offline use.

---

## 6. OpenRouter free models (`:free`) — what to expect

Free models are ordinary `openrouter` models whose ID ends in `:free`. Nothing special to
install: once the catalog is fresh they appear in `/model` and in `Ctrl+P`.

Live IDs present in the catalog today (re-check anytime with `pi --list-models`):

```
cohere/north-mini-code:free                        256K    64K
dots-studio/dots-3-note-preview:free               512K   460.8K
google/gemma-4-26b-a4b-it:free                     262.1K  32.8K
google/gemma-4-31b-it:free                         262.1K  32.8K
liquid/lfm-2.5-2.6b:free                           65.5K   8.2K
nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free 256K    65.5K
nvidia/nemotron-3-ultra-550b-a55b:free             1M      65.5K
nvidia/nemotron-3.5-lightning:free                 1M      65.5K
nvidia/nemotron-3.5-super-vl:free                  1M      131.1K
recursive/flint-v1.0:free                          262.1K  235.9K
thinkingmachines/inkling-small:free                1.0M    262.1K
thinkingmachines/inkling:free                      1.0M    262.1K
xingchen-agi/xing4.0-29b-a4b:free                  262.1K  235.9K
```

### Pin a free model so it survives a stale cache

Add to `~/.pi/agent/models.json` (a `models` entry is additive, and **replaces** the catalog
entry when the ID already exists — so carry `reasoning`/limits across, or the model loses them):

```json
{
  "$schema": "https://pi.dev/schemas/models.schema.json",
  "providers": {
    "openrouter": {
      "models": [
        {
          "id": "nvidia/nemotron-3.5-lightning:free",
          "name": "Nemotron 3.5 Lightning (free)",
          "contextWindow": 1024000,
          "maxTokens": 65536,
          "reasoning": true,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

### ⚠️ Corporate OpenRouter workspaces can block free models

Verified today with a Billtrust workspace key — the model lists fine but the request fails:

```
404: 0 endpoints out of 1 requested are available matching your guardrail restrictions
     and data policy.
     - model-ignored-by-guardrail       → openrouter.ai/workspaces/coding/guardrails
     - provider-not-allowed-by-guardrail → same
     - zdr-violation-by-account          → openrouter.ai/settings/privacy
     - zdr-violation-by-guardrail        → same
```

and one model returned `This model is unavailable for free. The paid version is available now`.

Also expect: free tiers are rate-limited, heavily throttled at peak, flaky with tool calling,
and withdrawn without notice (`deepseek/deepseek-r1:free` now returns
`no provider serves this model anymore`). **Use free models for throwaway experiments, not for
agentic repo work.** If requests fail with the guardrail/ZDR error, a workspace admin must allow
the provider in the workspace guardrail and/or relax the zero-data-retention policy — no pi
setting can override that. A personal OpenRouter account normally has neither restriction.

---

## 7. Team skills, extensions, and global instructions

Three separate things, all under `~/.pi/agent/`:

| Path | What goes there |
|---|---|
| `AGENTS.md` | Global instructions loaded every session (house rules, Jira/git policy) |
| `skills/<name>/SKILL.md` | Slash-command workflows (`/karthik-triage`, `/db-query`, …) |
| `extensions/*.ts` | Executable tools (e.g. `use-model.ts` for mid-session model switching) |

Setup options:

1. **Copy** the shared `AGENTS.md`, `skills/`, `extensions/` folders from a teammate's
   `~/.pi/agent/` (fastest, what we use today).
2. **Package** them for distribution (**[doc]**):

   ```powershell
   pi install git:github.com/BilltrustGH/<pi-package-repo>
   pi list
   pi update --extensions
   ```

   A package is a folder with `skills/`, `extensions/`, `prompts/`, `themes/` and a
   `package.json`; personal installs are recorded in `~/.pi/agent/settings.json`.

After copying anything new, run `/reload` inside pi.

**Do not copy** `auth.json`, `mcp-auth.json`, `mcp-cache.json`, or any local MCP server folder
containing keys (`mcp-checkmarx/`, `mcp-pendo/`). Each person signs in with their own account.

---

## 8. MCP servers

User-level file: `~/.pi/agent/mcp.json`. Add from the shell:

```powershell
# OAuth servers: no secrets in the file, sign in from pi afterwards
pi mcp add atlassian --url https://mcp.atlassian.com/v2/mcp
pi mcp add datadog   --url https://mcp.datadoghq.com/v1/mcp
pi mcp add slack     --url https://mcp.slack.com/mcp

# Token-based stdio server
pi mcp add github --env GITHUB_PERSONAL_ACCESS_TOKEN='${GITHUB_PERSONAL_ACCESS_TOKEN}' -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN ghcr.io/github/github-mcp-server

# Auth header piped through mcp-remote
pi mcp add splunk --env 'SPLUNK_MCP_AUTH_HEADER=${SPLUNK_MCP_AUTH_HEADER}' -- cmd /c npx -y mcp-remote https://billtrust.splunkcloud.com:443/en-US/splunkd/__raw/services/mcp --header 'Authorization: ${SPLUNK_MCP_AUTH_HEADER}'
```

Verified: `pi mcp add` writes/merges `~/.pi/agent/mcp.json` and prints the next step
(`If it requires sign-in: pi mcp login <server>`). Values in single quotes stay literal so the
`${VAR}` interpolation is done by pi at request time, not by your shell.

**Git Bash pitfall (verified):** running the same command from Git Bash mangles `cmd /c` into
`C:/` (MSYS path conversion) and the stored server breaks. Use `cmd //c` from Git Bash, or run
the command from PowerShell.

Then, inside pi:

```text
/mcp                 # status of every server
/mcp login atlassian # OAuth: opens browser, or paste the redirect URL
/mcp login datadog
/mcp login slack
/reload              # after editing mcp.json outside the session
```

Equivalent non-interactive: `pi mcp list`, `pi mcp login <server>`.
Tokens live in `~/.pi/agent/mcp-auth.json`; sign-ins are per person, never shared.

**Report disconnections immediately.** If any server shows as disconnected, run
`pi mcp login <server>` before starting work that depends on it — a silently dead Atlassian or
Datadog connector wastes a whole triage session.

---

## 9. Database access (MySQL) — read-only gateway

Never install a MySQL client or read credentials from `.env`. Use the shared gateway:

```powershell
C:\Users\<you>\GH\inv-ai-mysql-access\db-query.ps1
```

Requires Docker Desktop to be running. Environments reachable today: `billingmaster`,
`billingclient1`, `billingclient2` (no validation-stack DB through the gateway).

---

## 10. Verification checklist — all must pass before you call it done

```powershell
pi --version                     # prints a version
pi --list-models                 # lists your scoped chat models, no "No models match" warnings
pi --list-models ":free"         # shows free models if the catalog is fresh
```

Inside pi:

```text
!printf 'Bash is working\n'      # Git Bash resolved
/mcp                             # every expected server connected (green)
/model                           # picker opens; Ctrl+S saves a default
```

Then a real smoke test in a scratch folder:

```text
Summarize this repo's README in 3 bullets.
```

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No models matching "free"` / model missing from `/model` | stale `models-store.json` | `pi update --models`, or pin the model in `models.json` |
| `Warning: No models match pattern "<id>"` | `enabledModels` entry no longer exists | delete/fix that ID in `settings.json`, `/reload` |
| Auth works in one shell only | key came from an env var, not `auth.json` | `/login <provider>` to persist it |
| Free model returns 404 guardrail/ZDR | workspace guardrail or privacy policy blocks the provider | admin action in OpenRouter settings; try a paid slug instead |
| Free model returns `no provider serves this model anymore` | model withdrawn | pick another ID from `pi --list-models` |
| Model unavailable though configured in `models.json` | provider credentials unresolved | `/login` that provider; re-open `/model` |
| MCP tool missing | server disconnected | `/mcp`, then `pi mcp login <server>` |
| Windows MCP server stored with `"C:/"` instead of `"/c"` | ran `cmd /c ...` from Git Bash | re-add with `cmd //c`, or add from PowerShell |
| Editing config had no effect | file not re-read | `/reload` inside pi |
| Bash tool fails on Windows | Git Bash not found | install Git for Windows or set `"shellPath"` in `settings.json` |

---

## 12. Secrets hygiene

- `auth.json`, `mcp-auth.json`, and any MCP server folder with an embedded key are personal.
  Never paste them into a repo, a ticket, or a shared drive.
- Put tokens in environment variables or `!command` lookups in `models.json`/`mcp.json`
  (`"apiKey": "!security find-generic-password ..."`), not literals.
- Never run commands that echo credentials (e.g. `cx configure show` prints a live JWT).
