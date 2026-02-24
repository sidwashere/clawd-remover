# ClawD‑Remover

A **universal, cross‑platform removal utility** for ClawD/OpenClaw/MoltBot/Clawdbot deployments. This script is intended to completely eradicate any traces of the bots from a machine, regardless of how they were installed or which version is present. It works on macOS, Linux (including WSL), and Windows environments that provide a Unix‑like shell (Git Bash, Cygwin, etc.).

> ✅ **Designed for first‑click success.** Every stage runs automated verifications with helpful warning messages if anything is left behind.

---

## 📁 What the script does

1. **Stops running processes** matching common names (`openclaw`, `clawdbot`, `moltbot`, `clawd`, etc.).
2. **Cleans container engines** (`docker`/`podman`) if any ClawD images or containers exist.
3. **Removes launch agents and service units** on macOS and systemd user units on Linux.
4. **Uninstalls packages** through every major package manager (npm/pnpm/bun, brew, apt, yum, dnf, pacman, zypper, pip3).
5. **Wipes data directories** where credentials or caches may reside.
6. **Deletes leftover binaries** from system `PATH`.
7. **Performs final verification** to ensure no leftovers remain and prints a confirmation message.

---

## 🚀 Getting started

> **Step‑by‑step for absolute beginners**

1. **Download or clone** this repository to your computer.
   ```bash
   git clone https://example.com/your/repo/clawd-remover.git
   cd clawd-remover
   ```

2. **Make the script executable** (this only needs to be done once):
   ```bash
   chmod +x clawd-remover.sh
   ```

3. **Run the script** with sufficient privileges. Most removal tasks are harmless, but some operations (like deleting binaries from `/usr/local/bin`) may require `sudo` or Administrator rights.
   ```bash
   sudo ./clawd-remover.sh
   ```
   On Windows using Git‑bash you can usually run it without `sudo`.

4. **Watch the output carefully.**
   - Green `✅` messages mean the step completed successfully.
   - Yellow `⚠️` warnings indicate something may still exist; the script will try again automatically, but you can inspect and repeat the command if needed.
   - Red `❌` errors mean manual intervention is required.

   > 🎨 The tool now uses **ANSI color codes** for a friendly, relaxing look.  You'll see a spinning cursor during longer operations and may occasionally be rewarded with a fun "easter egg" message or piece of ASCII art in magenta – a small surprise to make the process less boring.

5. When the script finishes you will see a final confirmation:
   > 🎯 All checks passed. ClawD/Clawdbot removed successfully.

   If there were any leftover items, the script exits with a non‑zero status and tells you which things to look for.

6. **Extra precaution.** After a successful run, rotate any API keys, credentials, or secrets that the bot might have touched. The script will remind you with a security alert.

---

## 🧩 What if you still see ClawD components?

- **Processes still running?** Try rerunning the script with `sudo` or close your terminal and open a fresh one. On Windows, use Task Manager to kill stubborn tasks.
- **Binary still on PATH?** Manually inspect `which openclaw` / `which clawdbot` and remove the file or symlink shown.
- **Service unit or plist won't delete?** Check the file path printed in the warnings and remove it by hand; launch agents sometimes require a reboot to clear from `launchctl`.
- **Data directories remain?** They may be owned by another user; switch to that user or use `sudo rm -rf …`.

If you are unsure, open an issue in the repo or ask a teammate for help.

---

## 🛠 Maintenance and updates

- The script uses `set -euo pipefail` to stop early on unexpected errors.
- New target names or installation mechanisms can be added by editing the `TARGETS` array at the top of `clawd-remover.sh`.
- To add support for a new package manager, update the `package_uninstall` function.

---

## 📜 License & Credits

This tool is provided **as‑is** for educational and security purposes. Use it responsibly. Contributions and improvements are welcome—please open a pull request with your changes.

Happy cleaning! 🧼
