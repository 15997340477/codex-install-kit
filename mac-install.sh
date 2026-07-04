#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://nexus.1982video.cn"
KIT_URL_PRIMARY="https://gh.llkk.cc/https://raw.githubusercontent.com/15997340477/codex-install-kit/refs/heads/main/codex-install-kit-20260701-193335.zip"
KIT_URL_FALLBACK="https://gh-proxy.com/https://raw.githubusercontent.com/15997340477/codex-install-kit/refs/heads/main/codex-install-kit-20260701-193335.zip"

WORK="${TMPDIR:-/tmp}/codex-mac-install"
DMG="$WORK/Codex.dmg"
KIT="$WORK/codex-install-kit.zip"
EXTRACT="$WORK/extract"

mkdir -p "$WORK" "$HOME/Applications" "$HOME/.codex"

if [ "$(uname -m)" = "arm64" ]; then
  DMG_URL="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
else
  DMG_URL="https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg"
fi

echo "==> Downloading Codex app for macOS"
curl -L --fail "$DMG_URL" -o "$DMG"

echo "==> Installing Codex.app to ~/Applications"
MOUNT="$(hdiutil attach "$DMG" -nobrowse -readonly | sed -n 's|^.*\(/Volumes/.*\)$|\1|p' | head -n 1)"
if [ -z "$MOUNT" ] || [ ! -d "$MOUNT/Codex.app" ]; then
  echo "Could not find Codex.app in mounted DMG." >&2
  exit 1
fi
rm -rf "$HOME/Applications/Codex.app"
ditto "$MOUNT/Codex.app" "$HOME/Applications/Codex.app"
hdiutil detach "$MOUNT" >/dev/null

echo "==> Downloading config package"
curl -L --fail "$KIT_URL_PRIMARY" -o "$KIT" || curl -L --fail "$KIT_URL_FALLBACK" -o "$KIT"

echo "==> Extracting config package"
rm -rf "$EXTRACT"
mkdir -p "$EXTRACT"
unzip -q "$KIT" -d "$EXTRACT"

SKILLS_DIR="$(find "$EXTRACT" -type d -path "*/payload/skills" -print -quit)"
if [ -n "$SKILLS_DIR" ]; then
  rm -rf "$HOME/.codex/skills"
  ditto "$SKILLS_DIR" "$HOME/.codex/skills"
  echo "Copied skills to ~/.codex/skills"
else
  echo "No skills folder found in config package."
fi

echo "==> Writing Codex config"
cat > "$HOME/.codex/config.toml" <<EOF
model_provider = "custom"
disable_response_storage = true

[features]
goals = true

[model_providers.custom]
name = "nexus"
base_url = "$BASE_URL"
wire_api = "responses"
requires_openai_auth = true

[desktop]
conversationDetailMode = "STEPS_COMMANDS"
sansFontSize = 14
codeFontSize = 13
ambient-suggestions-enabled = false
localeOverride = "zh-CN"
followUpQueueMode = "queue"
EOF

printf "Enter Nexus API Key: "
stty -echo
read -r API_KEY
stty echo
printf "\n"

API_KEY="$(printf "%s" "$API_KEY" | tr -d '\r\n')"
if [ -z "$API_KEY" ]; then
  echo "API key is empty." >&2
  exit 1
fi

launchctl setenv OPENAI_API_KEY "$API_KEY"

SHELL_PROFILE=""
case "${SHELL:-}" in
  */zsh) SHELL_PROFILE="$HOME/.zshrc" ;;
  */bash) SHELL_PROFILE="$HOME/.bash_profile" ;;
esac

if [ -n "$SHELL_PROFILE" ]; then
  touch "$SHELL_PROFILE"
  if ! grep -q "OPENAI_API_KEY" "$SHELL_PROFILE"; then
    {
      echo ""
      echo "# Codex API key"
      echo "export OPENAI_API_KEY=\"$API_KEY\""
    } >> "$SHELL_PROFILE"
  fi
fi

echo "==> Testing proxy API"
curl -fsS -H "Authorization: Bearer $API_KEY" "$BASE_URL/v1/models" >/dev/null
echo "API test succeeded."

echo "==> Opening Codex"
open "$HOME/Applications/Codex.app"

echo "Done. In Codex, choose the model manually."
