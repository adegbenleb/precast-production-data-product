# Learning log

Write one entry for every real problem you hit. These entries become your interview stories, so be specific and honest. Use real error messages and real numbers from this project.

## Entry template
**Date / step:**
**What happened:** (the symptom, the exact error message if any)
**Cause:**
**What I did:** (the fix, with the tool or setting)
**Lesson:** (what you only learn by doing it)
**Business impact:** (why this would matter in a real company)

---

## Entry 1
**Date / step:** 2026-11-03, setup (before 0:00)
**What happened:** `dbt --version` worked and showed dbt-core 1.12.6, so dbt looked installed. But the only adapter listed was `postgres`, not `databricks`.
**Cause:** The shell still had another project's virtualenv active (`shopflow-brain/.venv`). The `dbt` on PATH belonged to that project, not this one.
**What I did:** Checked `which dbt` and `$VIRTUAL_ENV` to find where it came from. Gave this project its own uv environment with `dbt-databricks`, so the two projects never share packages.
**Lesson:** "The command runs" is not the same as "the right tool is installed". Check `which` and the adapter list, not only the version.
**Business impact:** On a team, a wrong or shared environment produces "works on my machine" failures and builds against the wrong adapter. Pinned per-project environments make dbt runs reproducible in CI and on a schedule.

## Entry 2
**Date / step:** 2026-11-03, setup (before 0:00)
**What happened:** `brew tap databricks/tap` failed with `Error: /opt/homebrew/Cellar is not writable` and `Permission denied @ rb_sysopen ... locks/...lock`.
**Cause:** Homebrew on this Mac is owned by a different macOS user account. Brew suggested `sudo chown -R` to take ownership, but that would break Homebrew for the other user.
**What I did:** Skipped brew. Downloaded the official Databricks CLI release (v1.23.0, darwin_arm64) from GitHub, verified it against the published SHA256SUMS, and installed it to `~/.local/bin`, a user-owned folder already on PATH. No sudo needed.
**Lesson:** Read the permission error before following the suggested fix. The "fix" printed by a tool can have side effects on other users. Official release binaries plus checksum verification are a clean fallback when a package manager isn't usable.
**Business impact:** On locked-down company laptops, admin rights and package managers are often unavailable. Knowing a no-sudo, verified install path keeps onboarding moving without weakening security.
