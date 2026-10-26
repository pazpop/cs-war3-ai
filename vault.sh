# shellcheck shell=bash
# Keeps the Ansible vault password in this terminal's memory, never on disk; Ansible reads it on its own, for 2 hours
# (or the given number of minutes). It stays in the terminal until it closes, and the programs started from it can
# read it: close the terminal when you are done.
# From the repository root, in Ubuntu:
#   source vault.sh      (or: source vault.sh 30)
# "source", not "bash" nor "./vault.sh": those run it in a shell of its own, which forgets the password at once.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "Run it with: source vault.sh" >&2
  exit 1
fi
read -rsp "Vault password: " VAULT_PASSWORD
echo
export VAULT_PASSWORD
VAULT_PASSWORD_EXPIRY=$(( $(date +%s) + ${1:-120} * 60 ))
export VAULT_PASSWORD_EXPIRY
ANSIBLE_VAULT_PASSWORD_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ansible/vault-password.sh"
export ANSIBLE_VAULT_PASSWORD_FILE
echo "Kept until $(date -d "@$VAULT_PASSWORD_EXPIRY" +%H:%M), in this terminal."
