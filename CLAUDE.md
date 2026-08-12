# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working  
with code in this repository.

## Overview

This is a macOS dotfiles repository managed as a git repo in ~/.config. It  
uses Fish shell as the primary shell with Starship prompt and Catppuccin  
Frappe theming throughout.

## Key Commands

### Setup & Bootstrap

    # Fresh machine (one-liner)
    curl -fsSL https://raw.githubusercontent.

com/dededecline/dotfiles/main/setup.sh | bash

    # Local setup
    ./setup.sh              # Run full setup (idempotent)
    ./setup.sh --brew       # Sync Homebrew packages only (declarative with --

cleanup) ./setup.sh --hostname nyx # Override hostname for testing ./setup.sh
--macos # Apply macOS system preferences only ./setup.sh --wallpaper # Override
wallpaper

### Secrets Management (1Password)

    secrets                         # Inject all secrets from 1Password
    secrets check                   # Check which secrets are configured
    ~/.config/.system/setup/secrets.sh --check  # Same as above (bash)

### Symlinks Only

    source ~/.config/.system/setup/symlinks.sh  # Just create symlinks

### Theme Sync

    ./.system/setup/sync-theme.sh          # Sync theme colors to all tool configs

Theme is defined in `.system/themes/theme.toml` (flavor + accent). The sync
script reads the palette and updates all downstream configs automatically. Runs
during full setup.

### Fish Shell

    refresh                         # Reload all configured processes
    refresh fish                    # Reload fish config only
    refresh aerospace               # Reload aerospace config only
    refresh sketchybar              # Reload sketchybar config only
    fishconfig                      # Edit fish config in nvim

## Architecture

### Setup Script

The setup.sh script is fully idempotent - run it anytime to ensure  
everything  
is configured:

• Installs Xcode CLT and Homebrew (if missing)  
• Clones dotfiles repository (if missing)  
• Injects secrets from 1Password (if authenticated)  
• Syncs Homebrew packages (declarative with --force-cleanup) • Syncs theme
colors to all tool configs • Generates Claude settings from machine-filtered
JSONC • Creates symlinks • Configures Fish shell as default  
• Installs Fisher and TPM  
• Applies macOS system preferences

Use --brew or --macos flags to run only those specific tasks.

### macOS Preferences

The .system/macos/.macos script sets system defaults via defaults write
commands:

• **UI**: Dark mode, auto-hide menu bar, expanded save panels  
• **Input**: Key repeat enabled, smart punctuation disabled, auto-correct  
disabled  
• **Finder**: POSIX path in title, hidden files visible, no desktop icons  
• **Screenshots**: PNG format, no shadow, saves to clipboard  
• **Sound**: System beep disabled  
• **Trackpad**: Tap to click disabled  
• **Security**: Touch ID for sudo authentication

Run standalone with ./setup.sh --macos.

### Homebrew Management

Homebrew packages are managed declaratively with brew bundle --force-cleanup.
`labels/` is the sole source of truth; `machines/<hostname>/Brewfile` is
**generated** at setup time by concatenating the label Brewfiles the machine
belongs to, then fed to `brew bundle`.

```
.system/profiles/
├── profiles.toml            # Machine-to-group membership (sole source of truth)
├── labels/                  # Edit these — source of truth
│   ├── all/Brewfile         # All machines
│   ├── laptop/Brewfile      # Laptop machines (athena, MacBook-Pro-HF7C7K3WJX)
│   ├── personal/Brewfile    # Personal machines (athena only)
│   ├── creative/Brewfile    # Gaming / DAWs (athena only)
│   ├── infra/Brewfile       # Infrastructure machines (MacBook-Pro-HF7C7K3WJX, nyx)
│   ├── server/Brewfile      # Server machines (nyx only)
│   └── work/Brewfile        # Work group (MacBook-Pro-HF7C7K3WJX only)
└── machines/                # Generated output — gitignored
    └── <hostname>/Brewfile  # Written by setup.sh prepare_brewfile()
```

Machine-to-group membership is defined in `.system/profiles/profiles.toml`
(TOML: `[hostname]` section with `groups = [...]`). Adding a new machine or
group requires only editing `profiles.toml` and optionally adding a labels
Brewfile directory — the `machines/` output is regenerated on every `setup.sh`
or `setup.sh --brew` run.

`profiles.toml` is the sole source of truth for defining machines and machine
groups. The `work` group gates 1Password work-account integration and work
secrets.

Notes on label assignments worth remembering: • `creative` is athena-only
(gaming + DAW content that shouldn't reach MacBook-Pro-HF7C7K3WJX or nyx). •
Claude Desktop (`cask "claude"`) lives in `laptop` — not `all` — so the server
(nyx) doesn't install a GUI app it can't use. • Claude Code CLI is installed via
the native installer (curl `claude.ai/install.sh`), not Homebrew. See
`install_claude_code` in `setup.sh`. Every `setup.sh` run also refreshes the
plugin marketplaces and updates all installed user-scope plugins to their latest
versions via `update_claude_plugins` (uses `claude plugin     list --json` +
`claude plugin update`; restart Claude Code to apply). • Python version
management is split by group: `uv` lives in `personal` (athena), `mise` in
`work` (MacBook-Pro-HF7C7K3WJX). `pyenv` was removed. The shared `all` group
keeps the editor-agnostic toolchain (`ruff`, `basedpyright`, `pipx`). `nyx`
(server) intentionally gets no version manager. Fish sets `UV_PYTHON=3.14`
(config.fish) so uv defaults to a stable interpreter; the `mise.fish` activation
is guarded by `type -q mise`, so it no-ops on non-work machines.

Tap trust: recent Homebrew refuses to load formulae/casks from non-official taps
until they are trusted (https://docs.brew.sh/Tap-Trust);
`HOMEBREW_REQUIRE_TAP_TRUST` defaults to on. Trust is declared **natively in the
Brewfiles** via the bundle `trusted:` option: every third-party `tap` line
carries `, trusted: true` (e.g. `tap "nikitabobko/tap", trusted: true`), which
trusts the whole tap and covers any qualified `brew`/`cask` ref under it.
`brew bundle` owns trust end-to-end: it applies `trusted:` options before it
loads anything (so a cold, untrusted machine still installs), and its
`--force-cleanup` pass rewrites the trust store to exactly the Brewfile-declared
set on every run (idempotent). Do **not** re-add a custom `brew trust` step in
`setup.sh`: `brew bundle --force-cleanup` calls `Homebrew::Trust.replace!` with
only the Brewfile's `trusted:` entries, so anything trusted outside the Brewfile
is wiped every sync (this was the old `trust_declared_taps` bug). When editing
Brewfiles: (1) add `, trusted: true` to any new third-party `tap` line; (2)
always use a tap's **canonical** name (e.g. `incident-io/tap`, not the
`incident-io/taps` alias that only resolves via a GitHub rename redirect) so
`cleanup_undeclared_taps` does not churn it untap/retap every run.

Keep entries alphabetized within each subsection of every `labels/*/Brewfile`. A
subsection is the contiguous block under a `#` comment header (both the
`# ===...===` major sections and the minor `# Category` headers inside
`# Applications (Casks)`). Sort case-insensitively by the first quoted
identifier (e.g. `brew "atuin"` → `atuin`, `cask "nikitabobko/tap/aerospace"` →
`nikitabobko/tap/aerospace`, `mas "Infuse", id: …` → `Infuse`). `brew` / `cask`
/ `tap` / `mas` lines in the same subsection sort together by name — do not
pre-group by type.

**`--verbose` is deliberately absent from the `brew bundle` call** in
`run_brew_sync`, and re-adding it is what causes the scrambled, misaligned
terminal output partway through a sync. It is not a verbosity level: `bundle.rb`
reads `return super cmd, *args if verbose`, so verbose shells out via
`Kernel#system` instead of capturing the child through `IO.popen`. Each child
`brew install` then **inherits the real TTY**, and since bundle installs in
parallel (`HOMEBREW_BUNDLE_JOBS=auto`, CPU cores capped at 4) several of them
write to that one TTY at once, outside the `@output_mutex` that guards only
bundle's own status lines. Each child now sees `$stdout.tty?` as true, which arms
Homebrew's in-place download redraw at `HOMEBREW_DOWNLOAD_CONCURRENCY=auto`
(cores x 2, so 20 here). That redraw emits `\033[nF` / `\033[K` and assumes
exactly one terminal row per download, so any extra row desyncs it and it
overwrites earlier output. Verbose supplies those extra rows directly: it strips
`--progress-bar` from curl (`utils/curl.rb`), restoring curl's multi-line `\r`
meter on all 20 workers, and enables a per-thread `ohai "Verifying checksum
for ..."`. The tell that this is overwriting rather than a stray-newline problem
is that whole lines go **missing**, not just misaligned.

The flag buys nothing to offset that. Per-package status
(`parallel_installer.rb`, `✔ Installing x` / `Using x`) and `--force-cleanup`
counts (`bundle/subcommand/cleanup.rb`, `Uninstalled N formulae`) are not
verbose-gated, and a failed child still prints its entire captured log via
`puts logs.join unless success`. Only successful output is suppressed.
`.system/tests/test-brew-sync.sh` pins this.

A second, **independent** mechanism produces a similar staircase: interactive
cask and pkg installers can exit leaving the TTY with **ONLCR disabled**, after
which a bare `\n` no longer returns to column 0. Upstream works around this for
its own messages by writing explicit `\r\n` (`parallel_installer.rb`), so a
staircase in *other* tools' output after a cask install is this, not a bug in
those tools.

`run_brew_sync` guards against it with `save_tty_state` / `restore_tty_state`,
which wrap the `brew bundle` call. They snapshot via `stty -g` and restore that
exact snapshot, deliberately **not** `stty sane`: sane resets the whole termios
struct to defaults, which would also silently discard intentional settings such
as `-ixon`. The restore sits outside the success/failure branch, because a failed
bundle is the case most likely to have left the terminal mangled. Both helpers
no-op when there is no controlling terminal, so `curl | bash` installs, CI, and
launchd are unaffected. The concrete damage is `oflag` losing its `ONLCR` bit
(`3` to `1` on macOS), which is what the pty test in `test-brew-sync.sh`
reproduces and reverses.

### Secrets System

The secrets system uses 1Password CLI (op inject) to populate sensitive  
values:

1. **Templates** (.system/templates/\*.tpl) - Files with
   {{ op://Vault/Item/Field }} references
2. **secrets.sh** - Processes templates and writes to .system/sensitive/
   directory
3. **.system/sensitive/** - Gitignored directory containing injected credentials

To add a new secret:

1. Create a template in .system/templates/ with op:// references
2. Add injection logic to .system/setup/secrets.sh
3. Document the required 1Password item in .system/templates/README.md

**Deliberate exception: `.system/sensitive/warpstream.fish`.** It is a static
file with no `.tpl` and no `secrets.sh` entry, sourced by
`fish/conf.d/warpstream.fish`. It was populated once from
`op://Employee/Warpstream` and is rotated by editing it in place. Do not
"complete" it by adding a template or an injection function; the point is that
WarpStream auth never depends on 1Password at runtime or on a setup run.

`WARPSTREAM_API_KEY` in that file holds the **application** key, because the
Terraform provider reads only that name. The agent reads the same variable as a
backward-compatible alias for its own agent key, so run an agent with an
explicit `-agentKey` flag (flags beat env vars) rather than relying on
`WARPSTREAM_AGENT_KEY` winning. Kafka-protocol access via `warpstream cli`/kcmd
needs separate SASL credentials from the cluster's Credentials page; an agent
key cannot be used as a SASL password.

WarpStream Bash permissions are deliberately three-tiered, not a blanket
`Bash(warpstream:*)`: read sub-commands (`describe-*`, `diagnose-*`,
`broker-metadata`, `consumer-group-lag`, `api-versions`, …) are allowed, the
three `delete-*` sub-commands are denied on `cli` and its `cli-old`/`cli-beta`
aliases, and everything else — `create-topic`, `create-acls`, `alter-*`,
`commit-offsets`, `console-producer`, `benchmark-*`, `agent`, `playground` — is
left unlisted so it prompts. Re-adding a blanket allow silently converts every
create and update into an unprompted action.

The deny list cannot cover `warpstream kcmd`, whose action is a `-type` flag
value rather than a positional sub-command, so prefix matching can't see it.
`kcmd` is therefore left entirely unlisted: it prompts for everything, reads
included. Prefix rules are a guardrail, not a boundary — an absolute path such
as `~/.warpstream/warpstream cli delete-topics` does not match them.

### Claude Skills Are Deny-by-Default

`claude/.gitignore` ignores `skills/*` and re-includes the **generic** skills by
name, one `!skills/<name>/` + `!skills/<name>/**` pair per skill, alphabetized.
The tracked set is the hand-written six (`1password`, `context7-mcp`, `gh-cli`,
`pdf-generation`, `python-pro`, `security-review`) plus the vendored third-party
sets described below. Everything else, including every 1Password-backed work
skill, stays hidden without anyone having to remember to deny it.

This replaced a `!skills/**` allowlist that was fail-open, where a work skill
was tracked unless explicitly denied by name. That shape let a new `aws` skill
documenting the internal SSO role inventory become committable to a public repo
silently. A skill that describes internal infrastructure belongs in 1Password
with the others, not in the repo.

The test for whether a skill is work-specific is simple: **would it make sense
on a machine that has never touched work?** `python-pro` yes, `aws` no.

#### Vendored third-party skills

Generic third-party skills are vendored verbatim as real directories under
`claude/skills/` (the python-pro pattern: snapshot, commit, keep upstream
frontmatter). `tile.json` and `evals/` files are inert upstream metadata kept
for provenance. Current sets and pinned sources:

- **mcollina/skills** (MIT, Matteo Collina), commit `a88a866`: `agents-md`,
  `documentation`, `node`, `nodejs-core`, `skill-optimizer`,
  `typescript-magician`. One local deviation: upstream `skills/init` is vendored
  as `agents-md` (directory and frontmatter `name` changed together) so it does
  not shadow Claude Code's bundled `/init`; a personal skill with the same name
  overrides a bundled one. Re-apply the rename on every refresh.
- **antonbabenko/terraform-skill** (Apache-2.0), v1.17.1: `terraform-skill`.
- **samber/cc-skills-golang** (MIT), snapshot 2026-08-12: the 46 `golang-*`
  skills. Quirk: `golang-project-layout/assets/.gitignore` is a template asset,
  but once tracked git honors it for future files under that `assets/` dir;
  nothing currently matches it.
- **vercel-labs/skills** (find-skills helper): `find-skills`.

**The `npx skills add` installer does not propagate.** It writes real skill
directories to `~/.agents/skills/` (user scope) or `<repo>/.agents/skills/`
(project scope) and drops symlinks into `claude/skills/`, which stay gitignored
by `skills/*` and invisible to `git status`. To make an installed skill
permanent, copy the real directory into `claude/skills/` (replacing the
symlink), add its allowlist pair to `claude/.gitignore`, and record its source
here. Refresh works the same way in reverse: re-fetch upstream, `diff -r`
against the vendored directory, re-copy, re-apply any deviation noted above,
and update the pinned ref in this list.

### Claude Rules

`claude/rules/*.md` load as global instructions in **every** session, unlike
skills which load on demand. They are split by whether their content is
work-specific:

| Rule | Home | Why |
|---|---|---|
| `code-comments.md` | tracked in repo | generic; must survive a fresh clone |
| `context7.md` | tracked in repo | generic; the `context7-mcp` skill defers to it |
| `pr-lint.md` | 1Password document `claude-rule-pr-lint` | names a real Linear prefix and an internal service |

Work rules follow the work-skills mechanism exactly: `inject_claude_rules()`
materializes them to `.system/sensitive/claude-rules/`, and `symlinks.sh` links
them into `claude/rules/`. Both are work-gated, so a personal machine gets
neither.

`claude/.gitignore` allowlists the two generic rules **by name** and ignores
`rules/*` otherwise, so a new rule file is hidden until someone deliberately
adds it. That is the safe default here: the cost of accidentally publishing a
work rule is higher than the cost of a rule not being version-controlled.

The tradeoff to know: a 1Password-backed rule **does not exist until `secrets`
has run**, and nothing announces a missing rule, so the guardrail is absent
rather than noisy. This is acceptable only because these rules are work-gated,
and a work machine that has not run `secrets` is already missing the work
skills, `clone.fish`, and the CI identity. Do not put a rule that must always
apply into 1Password; track a sanitized version instead.

`sync_op_document()` is the single implementation of the diff-and-prompt
`[l/r]` flow, shared by the work skills, the work rules, the global
instructions, and `~/.aws/config`. It was three near-identical copies, and the
bare-Enter-pushes-to-1Password bug had appeared in two of them independently.
`test-secrets-invariants.sh` asserts the prompt string appears exactly once, so
a fifth caller has to reuse the helper rather than re-inline it.

### Gitignore is an Allowlist

The root `.gitignore` **ignores everything at the top level** (`/*`) and
re-includes named entries with `!`. `claude/.gitignore` and `codex/.gitignore`
use the same deny-all-then-allowlist shape.

This is not stylistic. `~/.config` is where every application writes its config,
so ignoring by name structurally loses the race: `context7/`, `auth0/`, `ldcli/`,
`raycast/`, `akuity/`, `yarn/`, `vercel-plugin/` and `jgit/` all appeared on their
own, and `context7/` wrote an OAuth access token into a directory no rule
covered. A new tool's directory is now invisible to git until someone adds it
deliberately.

**Adding a new tracked directory takes two edits**: a `!/newdir/` line in the
top-level allowlist, and any ignore rules for generated or credential files
*inside* it. Forgetting the first means the files never appear in `git status`,
which reads as "nothing to commit" rather than as an error.

`1Password/` is allowlisted but immediately re-narrowed to just
`!/1Password/telemetry-enabled`, so the tracked telemetry opt-in survives while
anything else that tool writes stays out.

Verify a change to this file with:

    git ls-files | git check-ignore --stdin -v    # must print nothing

Any output means a tracked file just became ignored, which git will not
un-track for you and which silently freezes future edits to it.

### AWS Auth (work machines only)

Pure SSO. There is **no `~/.aws/credentials`** and no long-lived access key. One
login covers all 21 profiles because they share one SSO session:

    aws sso login --sso-session laurel     # or: lrl auth aws

The session must stay named `laurel`: the SSO token cache key is
sha1(session name), and that is how the `lrl` CLI locates the same token.

`~/.aws/config` is **hand-maintained and materialized from a 1Password document**
(`aws-config`, work account) by `inject_aws_config()` in `secrets.sh`. It uses the
same bidirectional pattern as `inject_claude_global`: diff, then prompt `[l/r]`.
It lives in 1Password rather than a repo template because its 5 AWS account ids
would otherwise be published, and because a per-account `op://` template would
lose the comment header, which is the actual value of the file.

That header documents a deliberate asymmetry: **`dev`/`stg`/`default` are
administrator while `prod` is read-only**, so mutating production requires the
explicit `prod-admin` profile. The stated reason is "the short, guessable name is
the safe one, so an agent that guesses `prod` cannot mutate production."

`settings.jsonc` backs this with denies on `aws --profile prod-admin`,
`lrl-prd-admin`, `lrl-prd-dbwrite`, `lrl-prd-oncall`, plus the `env AWS_PROFILE=`
and bare `AWS_PROFILE=` assignment forms. Same caveat as the warpstream block
above: prefix matching cannot see a `--profile` flag that appears *after* the
subcommand, and it cannot see an `AWS_PROFILE` exported in an earlier turn. It is
a guardrail, not a boundary. IAM is the boundary.

`lrl-prd-dbread` and `lrl-prd-dbwrite` are **escalation-gated**, not
misconfigured: standing state is no access, and `lrl auth aws` reports them as
"No access -> Requires escalation" while every other profile validates.

**`lrl init` re-serializes `~/.aws/config` and strips comment-only blocks** even
when it reports "No changes required"; `lrl init --force` drops the hardening
keys outright. Prefer not to run either. Recovery after a flattening is `secrets`,
then `r` to take the 1Password copy. The durable local backup is
`~/.aws/config.bak.20260810`.

`lrl auth` is a unified entry point covering `aws`, `argocd`, `signadot`,
`observe`, and `spacelift`. The first three are the supported way to authenticate
those tools. Treat `lrl auth spacelift` and `lrl auth observe` with suspicion:
Spacelift here relies on a permanent API key that a browser flow would replace
with a 10-hour JWT, and the observe skill documents that its browser login 404s.
Neither has been verified against the persistent credentials.

### Spacelift Auth (work machines only)

`inject_spacelift()` in `secrets.sh` fans the single `spacelift-api-key` item
(work account, `Employee` vault) out into three artifacts, because the three
consumers read three different places and none of them share:

- `.system/sensitive/spacelift-api-key.fish` — env vars, the **only** input the
  Spacelift Terraform provider accepts
- `~/.spacelift/config.json` — spacectl profile, `type: 1` (API key). This is
  the self-refreshing kind: `client/session/api_key.go` re-exchanges the JWT
  whenever it goes stale, so it never needs a manual login. spacectl resolves
  env first, then this file, so it also covers GUI apps and LaunchAgents that
  never see a fish environment.
- `~/.terraform.d/credentials.tfrc.json` — OpenTofu module registry

Both `$HOME` artifacts are written outside this repo, so no gitignore rule is
load-bearing for keeping them out of git.

**Never run `tofu login spacelift.io`** (and note the `spacelogin` alias now
points at `secrets --spacelift`, not at it). That command writes a
browser-issued Google SSO JWT with a **10-hour** lifetime, replacing a
credential that does not expire. It is the entire cause of the recurring
`401 Unauthorized ... error looking up module versions`. A 401 now means the API
key itself was revoked; fix it with `secrets --spacelift`.

Writing to `credentials.tfrc.json` rather than `~/.tofurc` is deliberate.
OpenTofu's `cliconfig.LoadConfig` merges the config **directory**
(`~/.terraform.d/*.tfrc`, `*.tfrc.json`) *after* the main config file, so a
credential in the directory silently shadows a `~/.tofurc` block. Full
precedence is `TF_TOKEN_*` env > CLI-config credentials > `credentials_helper`.

When probing the registry by hand, **check the version count, not the status
code**: an unauthenticated request returns HTTP 200 with an empty `versions`
array, so `%{http_code}` reports success on a dead credential.

### Symlinks

Traditional dotfiles that expect ~/. are symlinked:

• git/config → ~/.gitconfig  
• .system/sensitive/.npmrc → ~/.npmrc

### Display Monitor System

Automatically detects display connection/disconnection and reloads aerospace and
sketchybar configurations. Runs as a LaunchAgent that checks every 3 seconds.

Monitor definitions (resolution, refresh rate, serial, arrangement) are
configured in `.system/profiles/displays.toml`. The `display-profiles.sh` script
reads this TOML and builds displayplacer commands generically.

To add a new monitor: add a `[name]` section to `displays.toml` with `serial`,
`res`, `hz`, `color_depth`, and `dual_origin` keys. The `builtin` section is
special (no serial; detected at runtime).

Components: • .system/profiles/displays.toml - Monitor definitions (resolution,
serial, layout) • .system/setup/display-profiles.sh - Data-driven display
profile application • .system/setup/monitor-watcher.sh - Detects display count
changes using system_profiler • .system/setup/reload-display-config.sh - Reloads
configs when changes detected • .system/templates/display-monitor.plist.tpl -
LaunchAgent configuration

The system logs to ~/.config/logs/display-monitor.log and is automatically
loaded by setup.sh if aerospace and sketchybar are installed.

### Spotlight Shortcuts LaunchAgent

macOS re-enables Spotlight keyboard shortcuts on every restart. A LaunchAgent
runs .system/setup/disable-spotlight-shortcuts.sh at login to re-disable
shortcuts 64, 65, and 160, preventing conflicts with Raycast.

Components: • .system/setup/disable-spotlight-shortcuts.sh - Disables shortcuts
via defaults write and activateSettings •
.system/templates/spotlight-shortcuts.plist.tpl - LaunchAgent configuration

The script waits 10 seconds for macOS to finish boot-time restoration, then
applies the settings. Logs to ~/.config/logs/spotlight-shortcuts.log.

### Theme System

Theme colors are centralized via `.system/themes/theme.toml` (flavor + accent)
and `.system/themes/catppuccin-frappe/palette.toml` (hex values). The sync
script (`.system/setup/sync-theme.sh`) propagates colors to all tool configs:

- **Generated files**: sketchybar/colors.sh, lsd/colors.yaml,
  atuin/themes/\*.toml (full regeneration)
- **Section markers**: starship/starship.toml, fish/config.fish,
  fastfetch/config.jsonc, .system/templates/git-config.tpl (content between
  `@theme:start`/`@theme:end` replaced)
- **Flavor strings**: nvim, tmux, bat, atuin, kitty (flavor name updated)
- **Upstream files**: kitty.conf, bat.tmTheme, glow, zed themes (manual download
  for flavor changes)

To change themes: edit `.system/themes/theme.toml`, run
`.system/setup/sync-theme.sh`.

### Fastfetch Logos

One ASCII logo per machine: `fastfetch/logo_<hostname>.txt`.
`fastfetch/logo.txt` is a **gitignored symlink** created from `$MACHINE_HOSTNAME`
by `secrets.sh` (`inject_secrets`), so never edit `logo.txt` directly. Edit the
`logo_<hostname>.txt` file.

Logos render as horizontal colour stripes. Because `logo.type` is `"file"`
("printed with color code replacement"), fastfetch substitutes `$1`…`$9` in the
art with the matching `logo.color.N` from `config.jsonc`; the placeholders are
excluded from the computed logo width, so they do not shift the info column.
Every art line therefore starts with a `$N` prefix.

Stripe order (`logo.color.1`→`7`) mirrors the module list bottom-to-top, led by
the accent: lavender, blue, mauve, red, maroon, flamingo, rosewater. So the logo
runs cool-to-warm downward while the modules run warm-to-cool.

Stripe widths are as even as possible (max 1 row apart) and mirrored about the
centre, since the 16-row logos are vertically symmetric: 16 rows →
`2,2,3,2,3,2,2`; athena's 25 visible rows → `4,3,4,3,4,3,4`. Leading blank lines
ride along with stripe 1 rather than consuming one of its rows.

When adding a machine logo, prefix every line with `$1`…`$7` in order.
`sync_fastfetch` in `sync-theme.sh` keeps colours 1-7 (and the separator) in step
with the palette. Note it does **not** rewrite the module `keyColor` values,
which are hardcoded in the `modules` array; a flavour change leaves those stale
and they surface as `unknown color pattern` warnings.

### Claude Settings

`claude/settings.jsonc` is the source of truth for Claude Code settings.
`claude/settings.json` is generated by `setup.sh` using `@machine:<name>` /
`@end:<name>` markers. Markers accept hostnames or group names: •
`// @machine:MacBook-Pro-HF7C7K3WJX` — only on MacBook-Pro-HF7C7K3WJX •
`// @machine:laptop` — on MacBook-Pro-HF7C7K3WJX + athena •
`// @machine:personal` — on athena

Python type-checking in Claude Code uses **basedpyright** (matching Zed), via a
local in-repo plugin: `claude/local-plugins/` is a small marketplace
(`dotfiles`) whose `basedpyright-lsp` plugin points the LSP at
`basedpyright-langserver`. `setup.sh` registers the marketplace and installs the
plugin idempotently (see `update_claude_plugins`); `settings.jsonc` enables
`basedpyright-lsp@dotfiles` and disables the stock
`pyright-lsp@claude-plugins-official`. The marketplace path is declared in
`settings.jsonc` under `extraKnownMarketplaces` (`$HOME` expands at generation).

To modify settings: edit `claude/settings.jsonc`, then run `./setup.sh`.

**`mcpServers` is not a valid `settings.json` key.** A `"mcpServers"` block here
is silently ignored, not merged: a `@machine:work` block declaring the signadot
server sat in `settings.jsonc` for months while `claude mcp list` showed no such
server. MCP servers live in `~/.claude.json` (user and local scope) or a
project's `.mcp.json`; nothing else is read. Register user-scope servers with
`claude mcp add-json <name> --scope user '<json>'`.

The consequence is that user-scope MCP servers are **machine-local and not
reproducible from this repo**, since `~/.claude.json` also holds the OAuth
session and per-project state and so cannot be templated. Currently registered
at user scope: `context7`, `signadot`, `observe`, `warpstream`,
`warpstream-docs`. A fresh work machine needs those re-added by hand.

**Every credentialed MCP server uses `headersHelper`, with no exceptions.** This
is the one pattern; do not add a fourth shape. A helper reads the credential its
tool already owns and emits a JSON header, so there is exactly one write path,
nothing on argv, and no environment variable. Claude Code re-runs the helper and
retries once on a 401, so a refreshed token needs no session restart.

| Server | Helper | Credential |
|---|---|---|
| `observe` | `~/.observe/auth-header.sh` | `~/.observe/config.json`, written only by `observe auth configure` |
| `warpstream` | `.system/mcp/warpstream-header.sh` | `.system/sensitive/warpstream.fish`, rotated in place |
| `context7` | `.system/mcp/context7-header.sh` | `.system/sensitive/context7-api-key`, injected by `secrets` |

The helper scripts live in `.system/mcp/` and are **tracked**, because they hold
no secret. Only the credential files they read are gitignored.

Two shapes were deliberately removed, and re-adding either is a regression:

- **A token on argv.** `context7` was stdio with `--api-key <key>`, which left
  the key readable by any local user through `ps`. It is now HTTP transport.
- **`${VAR}` header interpolation.** `warpstream` interpolated
  `WARPSTREAM_MCP_API_KEY`, which forced that key to be exported into every
  shell, where the allow-listed `Bash(env:*)` could read it. Claude Code has
  **no** way to scrub inherited environment variables (the `env` key in
  `settings.json` only sets them, unlike Codex's `shell_environment_policy`
  `exclude`), so not exporting a secret is the only control available. That key
  is now `set -g` rather than `set -gx` in `warpstream.fish`.

`WARPSTREAM_API_KEY` and `WARPSTREAM_AGENT_KEY` remain exported because the
Terraform provider and the agent binary read them from the environment, as do
`SPACELIFT_API_KEY_*` and `GITHUB_PERSONAL_ACCESS_TOKEN`. So the Bash tool's
environment still holds secrets; the point is that none of them are there
*gratuitously*.

**When probing any credentialed endpoint by hand, assert on content, not status.**
Context7's MCP `initialize` returns HTTP 200 with a full capabilities response
for a made-up key; only a real `tools/call` returns "Invalid API key". The
Spacelift registry has the same shape (200 with an empty `versions` array). A
status-code check reports success on a dead credential.

### Codex Settings

`codex/config.source.toml` is the source of truth for OpenAI Codex CLI settings.
`codex/config.toml` is generated by `setup.sh` using the same `@machine:<name>`
/ `@end:<name>` markers as Claude, with `#` comment prefixes (TOML-native)
instead of `//`: • `# @machine:MacBook-Pro-HF7C7K3WJX` — only on
MacBook-Pro-HF7C7K3WJX • `# @machine:athena` — only on athena •
`# @machine:laptop` — on MacBook-Pro-HF7C7K3WJX + athena

`CODEX_HOME=$HOME/.config/codex` is exported in `fish/config.fish` so Codex
reads the generated config directly from this dir (mirrors `CLAUDE_CONFIG_DIR`).
`codex/config.toml`, `codex/hooks.json`, `codex/AGENTS.md`, and `codex/prompts/`
are symlinked into `~/.codex/` as fallbacks for shells or tools that read
Codex's default home.

`codex/hooks.json` is also generated by `configure_codex`, from
`codex/hooks.source.json`: the hook command paths use a literal `$HOME` that
`envsubst` expands to the current account's home per machine. The generated
`codex/hooks.json` is gitignored; edit `codex/hooks.source.json` to change hook
paths.

Install: `cask "codex"` in `.system/profiles/labels/laptop/Brewfile`
(laptop-only, mirroring `cask "claude"`).

Auth: run `codex login` interactively once per machine (no API-key injection;
uses ChatGPT subscription or API key written to `codex/auth.json`, which is
gitignored).

To modify settings: edit `codex/config.source.toml` (or
`codex/hooks.source.json` for hooks), then run `./setup.sh`.

### Kitty Fonts

Kitty on macOS has known issues with Homebrew cask-installed fonts (fonts
installed to ~/Library/Fonts/). Use NF (Nerd Font) cask variants that include
patched glyphs and set `font_family` to the registered family name with `auto`
for weight/style variants. The `symbol_map` for `Symbols Nerd   Font Mono`
provides fallback for any missing glyphs. Ligatures are enabled via
`disable_ligatures never`.

Always enable ligatures if the font supports them (`disable_ligatures   never`
in kitty.conf).

Current font: `Maple Mono NF` (cask: `font-maple-mono-nf`)

To change kitty's font:

1. Add the font cask to Brewfile and run `brew bundle`
2. Find the registered family name: `fc-list | grep "<font name>"`
3. Set `font_family <Family Name>` in kitty/kitty.conf with `auto` for
   bold/italic/bold-italic variants
4. Restart kitty (config reload alone may not pick up new fonts)

### Remote Access

Remote desktop and SSH access from laptops (MacBook-Pro-HF7C7K3WJX, athena) to
server (nyx) via RustDesk over Tailscale.

**Server (nyx):**

- `brew "tailscale"` (CLI formula) — runs `tailscaled` daemon for Tailscale SSH
- RustDesk server — configured by `.system/setup/rustdesk.sh` with permanent
  password
- macOS Application Firewall enabled in stealth mode
- Authenticates as **`tag:homeserver`**, not as a user — the same tag the other
  home server in the tailnet already uses, so the existing policy rules cover nyx
  without a policy edit. Tagged devices get key expiry disabled automatically, so
  there is no manual admin-console click to forget, and re-auth stays scriptable.
  Two consequences: tagged nodes are **not** covered by `autogroup:self` rules and
  need a rule naming the tag, and nyx cannot Tailscale-SSH *out* to user-owned
  devices (plain OpenSSH outbound is fine).
- **SSH in as `root`**, not as the local account: the tailnet's ssh rule for
  `tag:homeserver` grants `users: ["root"]`. `ssh <you>@nyx` is denied by policy.

**`ListenAddress` does not restrict anything on macOS.** `tailscale.sh` pins it to
the current Tailscale IP, but `/System/Library/LaunchDaemons/ssh.plist` uses
`inetdCompatibility` with a `Sockets` entry, so **launchd** owns the listening
socket and sshd runs per-connection in inetd mode, where it never binds and
`ListenAddress` is inert. The plist sets no `SockNodeName`, so it listens on all
interfaces. Tailscale SSH only claims port 22 *on the Tailscale IP*; LAN
connections still reach the system sshd. The real controls are the tailnet policy
and the Application Firewall. Check what is actually listening with:

    sudo lsof -nP -iTCP:22 -sTCP:LISTEN

Do not "fix" the ListenAddress block by trusting it — the accurate fix would be a
pf anchor limiting port 22 to `100.64.0.0/10`, which is deliberately not done
because a pf mistake on a remote-only machine is its own lockout risk.

**Laptops (MacBook-Pro-HF7C7K3WJX, athena):**

- `cask "tailscale-app"` (GUI) — one-time manual step: Settings > Install CLI
  integration
- RustDesk client — connect using Tailscale IP (100.x.x.x) or MagicDNS hostname

**Scripts:**

- `.system/setup/tailscale.sh` — enables Tailscale SSH, pins SSH ListenAddress,
  and warns (never acts) on tailnet drift
- `.system/setup/rustdesk.sh` — configures RustDesk for direct IP access
- `.system/setup/tailnet-switch.sh` — operator entry point for moving nyx between
  tailnets
- `.system/setup/tailnet-switch-worker.sh` — the switch itself, run by launchd
- `.system/setup/lib/tailnet.sh` — pure helpers, unit-tested by
  `.system/tests/test-tailnet-switch.sh`

**Manual steps — server (nyx):**

- RustDesk: Accessibility, Screen Recording, Input Monitoring (System Settings >
  Privacy & Security)
- Tailscale: authenticated by `tailnet-switch.sh`. Key expiry needs no manual
  step because the node is tagged.

### Moving nyx to a Different Tailnet

nyx is reachable **only** over the tailnet, so a foreground `tailscale login`
kills the very session running it: a Tailscale SSH session is a child of
tailscaled. The cutover is therefore owned by a one-shot LaunchDaemon.

    bash ~/.config/.system/setup/tailnet-switch.sh              # cutover
    bash ~/.config/.system/setup/tailnet-switch.sh --policy     # print policy requirements

Target tailnet and credential come from 1Password via `secrets` (see
`.system/templates/README.md` for the `Tailscale Server` item). The tailnet name
lives in 1Password rather than a repo constant because this repo is public.

The order matters: **the target tailnet's policy must already grant the tagged
node access before cutover**, because nothing on nyx can check that beforehand.
`--policy` prints the requirements. The reason nyx reuses `tag:homeserver` rather
than introducing its own tag is precisely this: an existing, reachable machine
under that tag proves the policy already covers a new node carrying it, so the
cutover needs no policy edit and no edit-ordering risk. A new tag would need a
tagOwners entry plus an ssh rule landed first — and would not even be selectable
when creating the OAuth credential until tagOwners knew about it.

How the safety works:

- `tailscale login` **adds** a profile rather than replacing the active one, so
  the old tailnet stays available for rollback. The worker verifies this rather
  than assuming it, and logs loudly if the old profile disappeared.
- The worker waits for `BackendState == Running`, an assigned address, **and** a
  matching `CurrentTailnet.Name` before declaring success. A Running backend on
  the wrong tailnet means the credential belonged elsewhere.
- Post-switch fixups reuse `tailscale.sh` as a subprocess (not sourced — it sets
  `set -e`). Because it derives `ListenAddress` from live state, the same script
  serves both directions: forward it writes the new IP, on rollback the old one.
- Peer **visibility** reflects the policy; **online** only reflects whether a
  device is powered on. So an empty peer list rolls back, while peers present but
  all asleep only warns. Failing on "nothing online" would roll back spuriously
  whenever the cutover ran while the other machines slept.
- Any failure switches back, restores the old SSH config, and logs the failing
  check to `~/.config/logs/tailnet-switch.log`.

The daemon deletes itself when done. It is deliberately **not** installed by
`secrets.sh` like the other plists: `RunAtLoad` in `/Library/LaunchDaemons` would
replay the switch on every boot. The worker is also a no-op when already on the
expected tailnet, which makes an interrupted run safe to repeat.

After a successful cutover: nyx's Tailscale IP has changed, so update the RustDesk
entries on the laptops (the RustDesk ID and permanent password are unchanged).
Once confident, delete the stale nyx node from the old tailnet's admin console and
drop the old profile — until then it is the rollback path.

**Manual steps — laptops (MacBook-Pro-HF7C7K3WJX, athena):**

- Tailscale: Allow Network Extension when prompted, Settings > Install CLI
  integration

**Claude Code auth:** API-key auth is a **server-only (nyx) concept**. Laptops
(athena, MacBook-Pro-HF7C7K3WJX) use claude.ai login auth: run `claude` and log
in once per machine.

nyx runs headless over SSH with no Keychain access, so it cannot complete a
login flow. It alone uses `apiKeyHelper`, which reads the key via a helper
script (no env var or OAuth needed).

- Gating: `"apiKeyHelper"` sits in a `// @machine:server` block in
  `claude/settings.jsonc`, and `secrets.sh` injects the key and generates the
  helper only for the `server` group. `secrets --check` reports on both only
  for server machines.
- Helper script: `~/.config/.system/sensitive/claude-api-key-helper.sh` (reads
  `anthropic-api-key` from the same sensitive directory, from
  `op://Private/anthropic-claude-api`)
- `claude/settings.jsonc` is the source of truth; `setup.sh` generates
  `claude/settings.json` from it. `apiKeyHelper` does NOT work in
  `~/.claude.json`.

Do **not** add `apiKeyHelper` to a laptop. When Claude Code resolves auth from
an API key it stops loading claude.ai connectors entirely, so every org
connector (Gmail, Drive, Calendar, Slack, ...) silently disappears.

### Global Claude Instructions

Source of truth lives in 1Password (<Personal Vault> > Private vault, Document
`claude-global-instructions`), not in the repo. On every `setup.sh` run
(including `--brew` and `--macos`), `secrets.sh` materializes the document to
`.system/sensitive/CLAUDE.global.md` (mode 600), and `symlinks.sh` links it into
`~/.claude/CLAUDE.md` so it applies to all repos.

Drift between local and remote is handled bi-directionally (mirroring the
claude-skills pattern): on a diff, the script prompts `[l/r]`. Choosing `l`
pushes the local copy back to 1Password via `op document edit`; choosing `r`
overwrites local with the 1Password copy.

To refresh on demand without a full setup run: `secrets --claude-global` (or
`bash .system/setup/secrets.sh --claude-global`).

### Agent Hooks

Hook scripts live at `.system/hooks/` (tool-neutral) and are referenced by both
Claude (`claude/settings.jsonc`) and Codex (`codex/hooks.json`, generated from
`codex/hooks.source.json`):

• `.system/hooks/git-guard.sh` — PreToolUse hook enforcing git workflow rules •
`.system/hooks/check-shell.sh` — PostToolUse hook for shell-script lint
(shellcheck + shfmt) • `.system/hooks/check-python.sh` — PostToolUse hook for
`.py`/`.pyi` files: auto-applies `ruff format` and `ruff check --fix`, then
blocks on remaining lint violations or basedpyright **errors** (warnings do not
block, so loosely-typed scratch code is not nagged) •
`.system/hooks/session-start.sh` — SessionStart hook

`git-guard.sh` enforces: • **All repos**: Blocks `Co-Authored-By` trailers and
`--author` overrides • **Pinginc repos**: Requires conventional commit format
(`type: LINEAR-ID: description`) • **Pinginc repos**: Blocks pushing directly to
main/master

Pinginc repos are detected dynamically via `git remote -v`, so hooks are
registered with no `@machine:` marker — the pinginc checks are runtime-gated.

### Fish Functions

Custom functions in fish/functions/:

• refresh - Reload configured processes (aerospace, sketchybar, fish, tmux) •
secrets - Wrapper for secrets.sh  
• gitdone - Switch to default branch and pull  
• clone - Clone one or more work repos, checking each name resolves (`-s`: no prompts)  
• empty - Create empty commit with CI identity for triggering pipelines  
• awsp - Switch the active AWS profile (`awsp` alone lists them; `awsp -` clears)  
• awsall - Run an AWS CLI command across all **regions** (not profiles)  
• \_\_awsp_profiles - Parse `~/.aws/config` into profile/account/role rows  
• \_\_awsp_account_id - Print one profile's `sso_account_id`

`awsall` fans out over `aws ec2 describe-regions`, not over profiles. It refuses
`--region`, and it demands interactive confirmation when the caller identity is
the production account, refusing outright when non-interactive unless passed
`--yes-prod`. It resolves the production account id by reading
`__awsp_account_id prod-admin` rather than hardcoding it, because this repo is
public; an unreadable config yields an empty value, which forces the prompt
rather than silently disabling it.

`clone` takes one or more repo names and resolves every one with `gh repo view`
before cloning anything, because the old single-repo version never read gh's
exit status: a typo produced an empty archived flag and fell through to a raw
`git clone` ssh error. Resolution is a separate pass so every bad name is
reported before verbose clone output starts scrolling. It tells a missing repo
apart from a rejected token by matching gh's own stderr, since both exit 1, and
it skips a name whose directory already exists rather than letting git fail on
it mid-batch. Names are accepted bare, as `<org>/name`, or with a trailing
`.git`, and are deduplicated before validation rather than after, so a repeated
bad name is reported once instead of twice. Every distinct requested repo then
ends up either cloned or reported as failed, which is what makes the
`cloned N of M` total trustworthy, and the exit status is non-zero if any
failed, including repos skipped because they are archived and consent was not
given. `-s`/`--silent` answers the
archived prompt and also skips the offer to open the result in zed, since a flag
meant for unattended runs should not launch a GUI; non-interactively without it,
archived repos are skipped while the rest still clone. That editor prompt is
offered only when exactly one repo was cloned, which is both the case where
opening it is unambiguous and the condition that subsumes the "anything cloned
at all" check. A batch that ends with one survivor therefore still offers it.
`clone` is the one
function here that uses fish's `argparse` builtin: two spellings of one flag
plus variadic positionals is where the manual `contains --` extraction used by
`awsall` stops paying off, and argparse rejects a typo'd flag instead of
treating it as a repo name.

Completions for `awsp` and `clone` live in `fish/completions/`, and
`fish/conf.d/aws.fish` sets `AWS_PAGER` empty.

### Key Aliases

Modern CLI replacements (in fish/conf.d/aliases.fish):

• ls → lsd, cat → bat, find → fd, diff → difft, top → btop  
• k → kubectl, tf → tofu, vim → nvim  
• dotfiles - cd to ~/.config

### Local Overrides

Untracked files for machine-specific config:

• ~/.config/fish/config.local.fish

### Development Instructions

• Always protect the user's name, email address, place of work, and other  
sensitive data behind templates and 1Password  
• Always check if CLAUDE.md, README.md, and/or Commands.md need updating  
after making changes/updates  
• Always make package/application changes programatically via homebrew  
(ideally) or mas (if necessary)  
• ALways develop idempotently  
• Always add theming if possible. Currently, everything is themed to  
Catppuccin Frappe with Lavender Accents  
• Always attempt the simplest possible coding output solutions to a problem

• Always ensure that templated/protected files' generated output are excluded
from commit in the gitignore

### Tests

    bash .system/tests/test-brew-sync.sh
    bash .system/tests/test-profiles.sh
    bash .system/tests/test-secrets-invariants.sh
    bash .system/tests/test-settings-generation.sh
    bash .system/tests/test-tailnet-switch.sh

Plain bash, no framework: each check prints a line and the suite exits non-zero
if any fail.

`test-brew-sync.sh` sources `setup.sh` (same `main "$@"`-stripping trick as
`test-settings-generation.sh`), stubs `brew` into an argument recorder, and runs
`run_brew_sync` to pin the real `brew bundle` flags. It asserts `--verbose` is
absent (see the Homebrew Management section for why that flag garbles the
terminal) while `--force-cleanup` and `--file=` survive, so the fix cannot be
satisfied by dropping the declarative-sync contract instead. `prepare_brewfile`
and the tap-cleanup helpers are stubbed, which keeps the suite off the network
and stops it writing into `.system/profiles/machines/`.

It also covers the tty guard. The load-bearing case allocates a **real pty** via
`python3 -c 'import pty'`, disables `ONLCR` the way a cask installer does, and
asserts `restore_tty_state` returns `stty -g` to its exact prior value. That
distinguishes a working guard from one that merely runs without error, and it
fails loudly (rather than passing vacuously) if `ONLCR` could not be disabled in
the first place. A second pair of cases stubs the helpers to confirm
`run_brew_sync` restores on **both** the success and failure paths.

`test-profiles.sh` unit-tests `.system/setup/lib/profiles.sh` against a fixture
`profiles.toml` in a temp dir (`PROFILES_TOML` is overridable for exactly this
reason).

`test-secrets-invariants.sh` pins the credential system with static assertions
rather than behavioural tests, since every injection path needs a live 1Password
session. Each assertion exists because the corresponding bug was **silent in
normal use**: a bare Enter at an `[l/r]` prompt pushing local content over the
1Password copy (`l | L | *)`); `op inject -o` writing straight to the
destination, which both raced the `chmod 600` and truncated a working credential
when the lookup failed; a `rm -rf` before `tar xf` in the skill-archive path; an
unknown hostname silently skipping every group-gated secret; and a hardcoded
12-digit AWS account id in a tracked file.

It also enforces two structural properties worth keeping: every `.tpl` that
`secrets.sh` references must exist (the `gh-hosts.tpl` branch guarded a template
that never did), and every template carrying an `op://` reference must actually
be injected by something. Plus it asserts no tracked file is matched by
`.gitignore`, which is the guard rail for the allowlist described above.

When adding an assertion here, verify it can **fail**: several of these patterns
are easy to write vacuously. The account-id check originally used
`[^0-9][0-9]{12}[^0-9]`, which never matched, because the id it was written to
catch sat at end-of-line with no trailing character.

`test-tailnet-switch.sh` unit-tests `.system/setup/lib/tailnet.sh`, whose functions
are pure so the tailnet cutover logic is testable without a tailnet. The cases that
matter: `tailnet_active_profile_id` reads the **ID** column while the active marker
`*` sits on the *Account* column, and returns non-zero when nothing is marked (a
stale ID there would make the worker roll back to a profile that is not live). And
an empty expected tailnet name never matches, so a missing or blank
`tailscale-tailnet` file cannot make every tailnet look correct.

`test-settings-generation.sh` covers `setup.sh` marker filtering against the
real `claude/settings.jsonc`, pinning which machine gets which gated block
(notably that `apiKeyHelper` reaches nyx and neither laptop), that every
machine's output is valid JSON, and that a failed generation leaves the
existing `settings.json` intact. It sources `setup.sh` with its trailing
`main "$@"` line stripped, then `set +e` to re-enable failure assertions.

Two traps that section guards against: `configure_claude` redirects with `>`,
which truncates on open, so an unchecked `jq` failure wipes `settings.json`;
and `settings.jsonc` may only contain `@machine`/`@end` marker comments, since
any other `//` line survives preprocessing and then breaks `jq`.

`get_machine_groups` **errors to stderr and returns 1 for a hostname with no
section in profiles.toml**, rather than defaulting to `all <hostname>`. The old
silent default meant a renamed machine quietly lost every group-gated block
(`@machine:work` and friends) from its generated config instead of failing.

Callers must check it explicitly (`groups=$(get_machine_groups "$h") || return 1`).
Do not rely on `set -e` to propagate the failure: it is suppressed inside
`if`/`&&` conditions and that suppression extends into the called function's
body, and `symlinks.sh` does not set `-e` at all.

### Shell Script Quality (shellcheck)

All shell scripts must pass shellcheck with zero warnings. Follow these
practices:

• **Quote variables**: Always double-quote `"$variable"` expansions to prevent
word splitting and globbing (SC2086) • **Use `read -r`**: Always pass `-r` to
`read` to prevent backslash mangling (SC2162) • **Group redirects**: When
appending multiple commands to the same file, use `{ cmd1; cmd2; } >> file`
instead of individual redirects (SC2129) • **Intentional single quotes**: When
single quotes are correct (e.g. `envsubst '$HOME'` where the literal string must
reach the command), add `# shellcheck disable=SC2016` with a brief explanation
rather than "fixing" the quote style • **Disable directives**: Use inline
`# shellcheck disable=SCXXXX` only for genuine false positives, always with a
comment explaining why
