#!/usr/bin/env bash
# Pushes and deploys this project and pazpop.net (the folder next to this one; skipped if missing) when they have new
# commits. pazpop.net is only pushed: GitHub Actions deploys it.
# In Ubuntu, from anywhere:
#   ./deploy-all.sh          the projects with commits not pushed yet
#   ./deploy-all.sh --all    every project (a new VPS, or the monthly rebuild for the images' security updates)
# It shows what it will do and asks before doing it. Not config.yml: it can reboot the VPS, run it by hand.
set -euo pipefail

cd "$(dirname "$0")/.."
projects=(cs-war3-ai pazpop.net)
all=0
[ "${1:-}" = --all ] && all=1

todo=()
for project in "${projects[@]}"; do
  [ -d "$project/.git" ] || continue
  if ! git -C "$project" fetch -q origin main; then
    echo "$project: GitHub cannot be reached, skipped."
    continue
  fi
  if [ -n "$(git -C "$project" status --porcelain)" ]; then
    echo "$project: files not committed, skipped (commit or put them aside first)."
    continue
  fi
  if [ "$(git -C "$project" rev-parse --abbrev-ref HEAD)" != main ]; then
    echo "$project: not on main, skipped."
    continue
  fi
  if [ "$(git -C "$project" rev-list --count main..origin/main)" != 0 ]; then
    echo "$project: GitHub has commits this copy does not (git pull first), skipped."
    continue
  fi
  if [ "$(git -C "$project" rev-list --count origin/main..main)" != 0 ] || [ "$all" = 1 ]; then
    todo+=("$project")
    echo "== $project"
    git -C "$project" log --oneline origin/main..main
  fi
done

if [ ${#todo[@]} = 0 ]; then
  echo "Nothing to push or deploy."
  exit 0
fi
read -rp "Push and deploy ${todo[*]}? [y/N] " answer
[ "$answer" = y ] || exit 1

# The vault password, to deploy cs-war3-ai: vault.sh asks it, unless this terminal still has it.
if [[ " ${todo[*]} " == *" cs-war3-ai "* ]] &&
   { [ -z "${VAULT_PASSWORD:-}" ] || [ "$(date +%s)" -ge "${VAULT_PASSWORD_EXPIRY:-0}" ]; }; then
  # shellcheck source=vault.sh
  # The duration, always: without it, vault.sh would read this script's own argument (--all).
  source cs-war3-ai/vault.sh 120
fi

failed=()
for project in "${todo[@]}"; do
  echo "=== $project"
  if ! git -C "$project" push -q origin main; then
    failed+=("$project (push)")
  elif [ -f "$project/ansible/deploy.yml" ] && ! (cd "$project" &&
        ANSIBLE_VAULT_PASSWORD_FILE="$PWD/ansible/vault-password.sh" \
        ansible-playbook -i ansible/inventory.yml ansible/deploy.yml); then
    failed+=("$project (deploy)")
  fi
done

if [ ${#failed[@]} != 0 ]; then
  # Already pushed: without --all, the next run would find nothing new to deploy.
  echo "Failed: ${failed[*]}. Fix it, then: ./deploy-all.sh --all" >&2
  exit 1
fi
echo "Done: ${todo[*]}."
