---
name: Sudo Fingerprint
description: "Run privileged commands through the OpenCode TUI terminal so the user can authenticate sudo with a fingerprint or password. Use this whenever a task needs root: any command containing sudo or sudo -v, pacman -S/-R/-Syu, systemctl restart/enable/edit, writes under /etc, mount/umount, udevadm, or when a previous command failed with \"terminal is required\", \"no tty present\", \"a password is required\", or the user says \"usa a digital\", \"autentica com impressão\", \"senha do sudo\", \"root\", \"permissão negada\". Use it even when the user only says \"instala\", \"reinicia\" or \"edita /etc\" but the command needs root. Also use it to verify privileged changes. Never pipe a password to sudo -S."
---

# Sudo with fingerprint through the TUI terminal

## Why this skill exists

The agent's own shell has no interactive TTY. When `sudo` needs authentication, it cannot show the fingerprint/PAM prompt there, so the command fails or hangs. The OpenCode TUI terminal is a real PTY in the user's session: the prompt appears there, the user touches the sensor (or types the password), and authentication completes. Running the command in that terminal also keeps the sudo timestamp valid for that PTY, which matters on systems where sudo caches credentials per TTY.

Use the `tui` tools for this:

- `tui.open_terminal()` opens the session terminal without stealing keyboard focus.
- `tui.write_terminal({ text })` types text into it; include a trailing `\n` to execute.

## Shell compatibility

The user's interactive shell is **fish**, and the TUI terminal or the agent's shell tool may be bash, fish, or zsh depending on OpenCode's `shell` setting. Never assume the terminal shell is bash.

- Always invoke the helper through bash explicitly: `bash ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh ...`. This works from fish, bash, and zsh.
- Always wrap complex commands in `bash -c '...'`; do not rely on the terminal's shell for pipes, substitutions, or `$?`.
- Agent-side snippets (waiting, cleanup, log reading) must be POSIX and run through `sh`, or use the bundled `scripts/wait.sh`, so they work even if OpenCode is configured with `"shell": "/usr/bin/fish"`.
- Simple raw commands (`sudo pacman -Syu`, `systemctl restart ...`) are valid in fish and bash. Bash-only syntax (`$?`, `[[ ]]`, `for ...; do`) must not be sent as raw text to a fish terminal.

## When to use it

Use this flow for any command that needs root, including:

- `sudo ...`, `sudo -v`
- `pacman -S/-R/-Syu`, `systemctl restart/enable/mask`, `udevadm`, `mount`
- editing files under `/etc`, `/usr`, or other root-owned paths
- any command that failed with `sudo: a terminal is required to read the password` or `no tty present`

If `sudo -n true` succeeds, credentials are already cached and you can use the normal shell. Otherwise, use the TUI.

## Preflight

1. Confirm the `tui` tools are available. If they are not, do not pretend: tell the user the TUI tools need `experimental.client-mcp: true` and a restart, and ask them to run the command manually.
2. Generate a unique run id, for example `date +%Y%m%d-%H%M%S`. Append a short random suffix if several commands might run in parallel.
3. Announce what will happen: "Vou rodar isso no terminal do TUI. Toque no sensor quando o prompt aparecer."

## Standard flow: non-interactive command

1. Open the terminal:

   ```
   tui.open_terminal()
   ```

2. Send one line that runs the helper script:

   ```
   tui.write_terminal({ text: "bash ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh <run-id> -- <command>\n" })
   ```

   The default global path is:

   ```
   ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh
   ```

   If the skill lives elsewhere, use the absolute path of its `scripts/sudo-run.sh`.

3. Wait for the user to authenticate. The script writes:

   - `/tmp/opencode/sudo-<run-id>.log` — combined stdout/stderr
   - `/tmp/opencode/sudo-<run-id>.rc` — exit status of `sudo`

4. Wait from the agent shell using the POSIX helper (works from fish, bash, or zsh):

   ```bash
   sh ~/.config/opencode/skills/sudo-fingerprint/scripts/wait.sh <run-id> 60
   ```

   It prints `done exit=<status> after=<seconds>` when the command finishes, or `timeout after=<seconds>` if it is still running or waiting for the sensor.

5. If `wait.sh` times out, inspect the log tail and tell the user it is probably waiting for the sensor. Call `wait.sh` again with a longer timeout. Do not assume failure and do not resend the command while it may still be waiting.

6. Read the log, strip ANSI escapes if needed, and report the exit status:

   ```bash
   sed -r 's/\x1B\[[0-9;]*[mK]//g' /tmp/opencode/sudo-<run-id>.log
   ```

7. Clean up after reporting:

   ```bash
   rm -f /tmp/opencode/sudo-<run-id>.log /tmp/opencode/sudo-<run-id>.rc
   ```

## Complex commands

For pipes, redirections, multiple statements, or quoting that is hard to get right in one line, wrap the whole shell command:

```
tui.write_terminal({ text: "bash ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh <run-id> -- bash -c '<command>'\n" })
```

For a long or reusable script, write it with the `write` tool to `/tmp/opencode/sudo-<run-id>.sh`, then send:

```
bash ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh <run-id> -- bash /tmp/opencode/sudo-<run-id>.sh
```

Important details for complex commands:

- This explicit `bash -c` is mandatory when the terminal is fish. Fish syntax differs for pipes, variables, and status codes, so do not send a complex command raw.
- The helper already invokes `sudo`. Do not start the inner command with `sudo`, or it will run `sudo sudo ...`.
- Inside `bash -c`, the shell runs as **root**. `~` expands to `/root`, and your user aliases and functions are not available. Use absolute paths.
- For a script that mixes user steps and root steps, write the script and run it raw in the TUI (`bash /tmp/opencode/script.sh`), not through the helper. The helper would run the whole script as root.

Do not send multiple lines to the terminal. Each newline executes immediately, and a half-written command can do the wrong thing. Put multi-line logic in a script file.

## Interactive commands

Some commands need the user to interact after authentication (pacman confirmations, `visudo`, editors, full-screen tools). Do not wrap those in the capture script: a pipe on stdout can break full-screen programs and buffering. Send the raw command instead:

```
tui.write_terminal({ text: "sudo pacman -Syu\n" })
```

These simple commands are valid in fish and bash. If the interactive command needs arguments with pipes, substitutions, or several statements, write a script and run it raw in the TUI instead of sending fish/bash-specific syntax.

Let the user drive. When they are done, verify the result with a read-only command (`systemctl is-active`, `pacman -Q`, `test -f`). Never claim success from the absence of errors alone.

## Failure handling

- Exit code 1 and `Sorry, try again` / `Authentication failure`: the user cancelled or the fingerprint was not recognized. Ask whether to retry once; do not loop.
- Exit code 1 and `a terminal is required`: the command ran outside the TUI terminal. Re-run it through the helper script.
- No rc file and no log growth: the user may not have focused the terminal, or the command is still running. Ask before resending.
- Terminal closed: the command may have been killed. Check the log and verify the actual system state before retrying.

## Safety

- Never send a password, never use `echo <password> | sudo -S`, and never put secrets in the command, the log, or the chat.
- The log is created with `umask 077`, but it can still contain sensitive output. Delete it after reading. If the command may print secrets, run it without the capture script and summarize only what is needed.
- Show the exact command before sending when it is destructive or irreversible (`rm -rf`, `dd`, `mkfs`, `pacman -R`, edits to `/etc`). Get explicit confirmation if the user did not already ask for it.
- One command at a time. Do not type unrelated commands, `exit`, or control characters into the user's terminal.
- The terminal belongs to the user. If it looks busy, ask before writing.

## Fallbacks

- TUI tools unavailable: ask the user to run the command in their terminal, or enable `experimental.client-mcp` and restart.
- User prefers password: they can type it in the same TUI terminal; the flow is identical.
- `sudo -n true` succeeds: use the normal shell for simple read-only commands to save a round trip.

## Examples

**Install a package**

```
tui.write_terminal({ text: "bash ~/.config/opencode/skills/sudo-fingerprint/scripts/sudo-run.sh 20261104-1100-a1b2 -- pacman -S --noconfirm ripgrep\n" })
```

Tell the user to touch the sensor. Wait with `sh ~/.config/opencode/skills/sudo-fingerprint/scripts/wait.sh 20261104-1100-a1b2 60`, read the log, report, and clean up.

**Restart a service**

```
... -- systemctl restart docker
```

Then verify with `systemctl is-active docker` (no sudo needed).

**Edit a root-owned file**

Write the new content to a temp file, then:

```
... -- bash -c 'install -m 0644 /tmp/opencode/hosts.new /etc/hosts'
```

Verify with `cat /etc/hosts` (read-only, no sudo needed).
