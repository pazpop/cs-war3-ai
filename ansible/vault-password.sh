#!/usr/bin/env bash
# Called by Ansible (ANSIBLE_VAULT_PASSWORD_FILE, set by vault.sh): prints the password kept in this terminal,
# until it expires. Not meant to be run by hand.
if [ -z "${VAULT_PASSWORD:-}" ] || [ "$(date +%s)" -ge "${VAULT_PASSWORD_EXPIRY:-0}" ]; then
  echo "Vault password missing or expired: run \"source vault.sh\" again." >&2
  exit 1
fi
printf '%s\n' "$VAULT_PASSWORD"
