#!/bin/bash
# =====================================================================
#  VS Code "Pro" Setup - single-file installer (macOS)
#    1. writes settings.json
#    2. installs JetBrains Mono (per-user, no sudo)
#    3. installs the extension set (skips ones already present)
#    4. points Todo-Tree at VS Code's bundled ripgrep
#  Safe to re-run. Log: vscode-setup-log.txt next to this file.
#
#  Usage: double-click in Finder, or:  bash vscode-setup.command
# =====================================================================

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HERE/vscode-setup-log.txt"

# mirror everything to the log file
exec > >(tee "$LOG") 2>&1

C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
C_RED=$'\033[31m'; C_DIM=$'\033[90m'; C_OFF=$'\033[0m'

step() { printf '\n%s>> %s%s\n' "$C_CYAN" "$1" "$C_OFF"; }
ok()   { printf '   %s[ok]   %s%s\n' "$C_GREEN" "$1" "$C_OFF"; }
bad()  { printf '   %s[warn] %s%s\n' "$C_YELLOW" "$1" "$C_OFF"; }

finish() {
  local rc=$1
  printf '\n%s\n' '---------------------------------------------'
  printf ' Finished. Exit code: %s\n' "$rc"
  printf '%s\n' '---------------------------------------------'
  # only pause when launched by double-click (stdin is a tty)
  if [ -t 0 ]; then read -r -n 1 -p "Press any key to close..."; echo; fi
  exit "$rc"
}

printf 'Bash    : %s\n' "$BASH_VERSION"
printf 'macOS   : %s\n' "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
printf 'Folder  : %s\n' "$HERE"

# ---------------------------------------------------------------------
# 1) Locate the VS Code CLI
# ---------------------------------------------------------------------
step "Locating VS Code"

APP_ROOTS=(
  "/Applications/Visual Studio Code.app"
  "$HOME/Applications/Visual Studio Code.app"
  "/Applications/Visual Studio Code - Insiders.app"
  "$HOME/Applications/Visual Studio Code - Insiders.app"
)

CODE="$(command -v code 2>/dev/null || true)"
if [ -z "$CODE" ]; then
  for r in "${APP_ROOTS[@]}"; do
    for c in "$r/Contents/Resources/app/bin/code" "$r/Contents/Resources/app/bin/code-insiders"; do
      if [ -x "$c" ]; then CODE="$c"; break 2; fi
    done
  done
fi

if [ -z "$CODE" ]; then
  bad "Could not find the 'code' command."
  bad "Open VS Code -> Cmd+Shift+P -> 'Shell Command: Install 'code' command in PATH', then re-run."
  finish 1
fi
ok "CLI: $CODE"

# ---------------------------------------------------------------------
# 2) Find VS Code's bundled ripgrep (Todo-Tree needs an explicit path)
# ---------------------------------------------------------------------
step "Looking for bundled ripgrep"

RG=""
for r in "${APP_ROOTS[@]}"; do
  res="$r/Contents/Resources"
  [ -d "$res" ] || continue
  hit="$(find "$res" -type f -name rg -perm -u+x 2>/dev/null | head -n 1)"
  if [ -n "$hit" ]; then RG="$hit"; break; fi
done
# fall back to a ripgrep from Homebrew / PATH
if [ -z "$RG" ]; then RG="$(command -v rg 2>/dev/null || true)"; fi

if [ -n "$RG" ]; then ok "ripgrep: $RG"; else bad "Not found - Todo-Tree will be skipped"; fi

# ---------------------------------------------------------------------
# 3) Write settings.json
# ---------------------------------------------------------------------
step "Writing settings.json"

SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
SETTINGS="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

TMP_SETTINGS="$(mktemp -t vscode-settings)"
cat > "$TMP_SETTINGS" <<'JSON'
{
  // ─────────────────────────────────────────────
  //  THEME & LOOK
  // ─────────────────────────────────────────────
  "workbench.colorTheme": "Catppuccin Mocha",
  "workbench.iconTheme": "material-icon-theme",
  "workbench.productIconTheme": "material-product-icons",
  "catppuccin.italicComments": true,
  "catppuccin.italicKeywords": false,
  "catppuccin.boldKeywords": true,
  "catppuccin.colorOverrides": {
    "mocha": {
      "base": "#11111b",
      "mantle": "#0d0d15",
      "crust": "#0a0a11"
    }
  },
  "catppuccin.customUIColors": {
    "mocha": {
      "editorLineNumber.activeForeground": "accent",
      "statusBar.foreground": "accent"
    }
  },

  // ─────────────────────────────────────────────
  //  FONT
  // ─────────────────────────────────────────────
  "editor.fontFamily": "'JetBrains Mono', 'SF Mono', Menlo, Monaco, 'Courier New', monospace",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "editor.lineHeight": 1.65,
  "editor.letterSpacing": 0.3,
  "editor.fontWeight": "400",

  // ─────────────────────────────────────────────
  //  EDITOR — the "pro" feel
  // ─────────────────────────────────────────────
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.cursorWidth": 3,
  "editor.smoothScrolling": true,
  "editor.stickyScroll.enabled": true,
  "editor.minimap.enabled": false,
  "editor.renderLineHighlight": "all",
  "editor.renderWhitespace": "boundary",
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "editor.guides.indentation": true,
  "editor.linkedEditing": true,
  "editor.suggestSelection": "first",
  "editor.inlineSuggest.enabled": true,
  "editor.tabSize": 4,
  "editor.detectIndentation": true,
  "editor.rulers": [
    88,
    120
  ],
  "editor.wordWrap": "off",
  "editor.scrollBeyondLastLine": true,
  "editor.padding.top": 12,
  "editor.overviewRulerBorder": false,
  "editor.hideCursorInOverviewRuler": true,
  "editor.occurrencesHighlight": "multiFile",
  "editor.multiCursorModifier": "alt",
  "editor.acceptSuggestionOnEnter": "smart",
  "editor.quickSuggestions": {
    "other": "on",
    "comments": "off",
    "strings": "on"
  },

  // ─────────────────────────────────────────────
  //  SAVE / FORMAT
  // ─────────────────────────────────────────────
  "editor.formatOnSave": true,
  "editor.formatOnPaste": false,
  "files.autoSave": "onFocusChange",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "files.eol": "\n",

  // ─────────────────────────────────────────────
  //  WORKBENCH / UI CHROME
  // ─────────────────────────────────────────────
  "window.titleBarStyle": "custom",
  "window.commandCenter": true,
  "window.density.editorTabHeight": "compact",
  "window.nativeTabs": false,
  "window.title": "${rootName}${separator}${activeEditorMedium}",
  "workbench.startupEditor": "none",
  "workbench.editor.tabActionLocation": "right",
  "workbench.editor.highlightModifiedTabs": true,
  "workbench.editor.labelFormat": "medium",
  "workbench.list.smoothScrolling": true,
  "workbench.tree.indent": 16,
  "workbench.tree.renderIndentGuides": "always",
  "workbench.editor.empty.hint": "hidden",
  "workbench.layoutControl.enabled": false,
  "breadcrumbs.enabled": true,
  "explorer.compactFolders": false,
  "explorer.confirmDelete": true,
  "explorer.confirmDragAndDrop": false,
  "explorer.fileNesting.enabled": true,
  "explorer.fileNesting.patterns": {
    "*.ts": "${capture}.js, ${capture}.d.ts",
    "*.csproj": "*.sln, *.user, appsettings*.json, packages.config",
    "*.py": "${capture}.pyi",
    "platformio.ini": ".gitignore, .clang-format",
    "package.json": "package-lock.json, yarn.lock, pnpm-lock.yaml, .npmrc",
    "README.md": "LICENSE, CHANGELOG.md, CONTRIBUTING.md, .gitignore, .editorconfig"
  },

  // ─────────────────────────────────────────────
  //  TERMINAL
  // ─────────────────────────────────────────────
  "terminal.integrated.fontFamily": "'JetBrains Mono', 'SF Mono', Menlo, monospace",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.lineHeight": 1.3,
  "terminal.integrated.cursorBlinking": true,
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.smoothScrolling": true,
  "terminal.integrated.defaultProfile.osx": "zsh",
  "terminal.integrated.scrollback": 10000,
  "terminal.integrated.gpuAcceleration": "on",
  "terminal.integrated.macOptionIsMeta": true,

  // ─────────────────────────────────────────────
  //  GIT
  // ─────────────────────────────────────────────
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  "git.openRepositoryInParentFolders": "always",
  "diffEditor.ignoreTrimWhitespace": false,
  "diffEditor.renderSideBySide": true,
  "gitlens.currentLine.enabled": false,
  "gitlens.codeLens.enabled": false,
  "gitlens.hovers.currentLine.over": "line",

  // ─────────────────────────────────────────────
  //  ERROR LENS (inline errors)
  // ─────────────────────────────────────────────
  "errorLens.enabledDiagnosticLevels": [
    "error",
    "warning"
  ],
  "errorLens.fontStyleItalic": true,
  "errorLens.messageBackgroundMode": "message",
  "errorLens.gutterIconsEnabled": true,

  // ─────────────────────────────────────────────
  //  C# / .NET
  // ─────────────────────────────────────────────
  "[csharp]": {
    "editor.defaultFormatter": "ms-dotnettools.csharp",
    "editor.tabSize": 4,
    "editor.formatOnSave": true
  },
  "dotnet.inlayHints.enableInlayHintsForParameters": true,
  "dotnet.inlayHints.enableInlayHintsForTypes": true,
  "dotnet.inlayHints.enableInlayHintsForLiteralParameters": true,
  "dotnet.completion.showCompletionItemsFromUnimportedNamespaces": true,
  "dotnet.server.useOmnisharp": false,
  "csharp.inlayHints.enableInlayHintsForImplicitObjectCreation": true,
  "csharp.semanticHighlighting.enabled": true,

  // ─────────────────────────────────────────────
  //  PYTHON
  // ─────────────────────────────────────────────
  "[python]": {
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.tabSize": 4,
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      "source.fixAll.ruff": "explicit",
      "source.organizeImports.ruff": "explicit"
    }
  },
  "python.analysis.typeCheckingMode": "basic",
  "python.analysis.autoImportCompletions": true,
  "python.analysis.inlayHints.functionReturnTypes": true,
  "python.analysis.inlayHints.variableTypes": true,
  "python.terminal.activateEnvInCurrentTerminal": true,

  // ─────────────────────────────────────────────
  //  C / C++ / EMBEDDED (Arduino, ESP32, PlatformIO)
  // ─────────────────────────────────────────────
  "[cpp]": {
    "editor.defaultFormatter": "ms-vscode.cpptools",
    "editor.tabSize": 2
  },
  "[c]": {
    "editor.defaultFormatter": "ms-vscode.cpptools",
    "editor.tabSize": 2
  },
  "C_Cpp.clang_format_fallbackStyle": "{ BasedOnStyle: Google, IndentWidth: 2, ColumnLimit: 100 }",
  "C_Cpp.intelliSenseEngine": "default",
  "C_Cpp.inlayHints.parameterNames.enabled": true,
  "C_Cpp.inlayHints.autoDeclarationTypes.enabled": true,
  "C_Cpp.autocompleteAddParentheses": true,
  "platformio-ide.autoRebuildAutocompleteIndex": true,
  "platformio-ide.disablePIOHomeStartup": true,
  "files.associations": {
    "*.ino": "cpp",
    "platformio.ini": "ini"
  },

  // ─────────────────────────────────────────────
  //  JSON / YAML / MARKDOWN / SQL
  // ─────────────────────────────────────────────
  "[json]": {
    "editor.defaultFormatter": "vscode.json-language-features",
    "editor.tabSize": 2
  },
  "[jsonc]": {
    "editor.defaultFormatter": "vscode.json-language-features",
    "editor.tabSize": 2
  },
  "[markdown]": {
    "editor.wordWrap": "on",
    "editor.quickSuggestions": {
      "other": "on"
    }
  },
  "[yaml]": {
    "editor.defaultFormatter": "redhat.vscode-yaml",
    "editor.tabSize": 2
  },

  // ─────────────────────────────────────────────
  //  MISC / PERFORMANCE
  // ─────────────────────────────────────────────
  "security.workspace.trust.untrustedFiles": "open",
  "telemetry.telemetryLevel": "off",
  "update.showReleaseNotes": false,
  "extensions.ignoreRecommendations": false,
  "search.exclude": {
    "**/node_modules": true,
    "**/bin": true,
    "**/obj": true,
    "**/.pio": true,
    "**/__pycache__": true,
    "**/.venv": true,
    "**/dist": true
  },
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/.pio/**": true,
    "**/bin/**": true,
    "**/obj/**": true,
    "**/.venv/**": true
  },
  "cSpell.enabled": true,
  "cSpell.diagnosticLevel": "Hint",
  "better-comments.tags": [
    {
      "tag": "!",
      "color": "#f38ba8",
      "bold": true
    },
    {
      "tag": "?",
      "color": "#89b4fa"
    },
    {
      "tag": "todo",
      "color": "#f9e2af",
      "bold": true
    },
    {
      "tag": "*",
      "color": "#a6e3a1"
    }
  ]
}
JSON

# hand Todo-Tree an explicit ripgrep path (first line of the file is "{")
if [ -n "$RG" ]; then
  TMP2="$(mktemp -t vscode-settings2)"
  awk -v rgp="$RG" 'NR==1 { print; printf "  \"todo-tree.ripgrep\": \"%s\",\n", rgp; next } { print }' \
    "$TMP_SETTINGS" > "$TMP2"
  mv "$TMP2" "$TMP_SETTINGS"
fi

if [ -f "$SETTINGS" ]; then
  cp -f "$SETTINGS" "$SETTINGS.bak"
  ok "Backed up old settings -> settings.json.bak"
fi
cp -f "$TMP_SETTINGS" "$SETTINGS"
rm -f "$TMP_SETTINGS"
ok "Wrote $SETTINGS"

# ---------------------------------------------------------------------
# 4) JetBrains Mono (per-user install, no sudo)
# ---------------------------------------------------------------------
step "JetBrains Mono font"

FONT_DIR="$HOME/Library/Fonts"
FONT_URL="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
mkdir -p "$FONT_DIR"

existing="$(ls "$FONT_DIR"/JetBrainsMono*.ttf 2>/dev/null | wc -l | tr -d ' ')"
if [ "$existing" -ge 4 ]; then
  ok "Already installed ($existing files) - skipping"
else
  work="$(mktemp -d -t jbmono)"
  zip="$work/JetBrainsMono.zip"
  echo "   downloading..."
  if curl -fsSL --retry 2 -o "$zip" "$FONT_URL" && unzip -qo "$zip" -d "$work/x"; then
    ttfs=()
    while IFS= read -r f; do ttfs+=("$f"); done < <(find "$work/x" -type f -name '*.ttf' -path '*/ttf/*')
    if [ "${#ttfs[@]}" -eq 0 ]; then
      while IFS= read -r f; do ttfs+=("$f"); done < <(find "$work/x" -type f -name '*.ttf')
    fi
    if [ "${#ttfs[@]}" -gt 0 ]; then
      for f in "${ttfs[@]}"; do cp -f "$f" "$FONT_DIR/"; done
      ok "Installed ${#ttfs[@]} font files"
    else
      bad "No .ttf files inside the archive"
    fi
  else
    bad "Font download failed"
    bad "Not fatal - VS Code falls back to SF Mono / Menlo."
  fi
  rm -rf "$work"
fi

# ---------------------------------------------------------------------
# 5) Extensions (only the missing ones)
# ---------------------------------------------------------------------
step "Extensions"

extensions=(
  'catppuccin.catppuccin-vsc'
  'pkief.material-icon-theme'
  'pkief.material-product-icons'
  'usernamehw.errorlens'
  'eamodio.gitlens'
  'mhutchie.git-graph'
  'editorconfig.editorconfig'
  'aaron-bond.better-comments'
  'christian-kohler.path-intellisense'
  'streetsidesoftware.code-spell-checker'
  'ms-dotnettools.csharp'
  'ms-dotnettools.csdevkit'
  'ms-dotnettools.vscode-dotnet-runtime'
  'ms-python.python'
  'ms-python.vscode-pylance'
  'ms-python.debugpy'
  'charliermarsh.ruff'
  'ms-vscode.cpptools-extension-pack'
  'platformio.platformio-ide'
  'ms-vscode.hexeditor'
  'redhat.vscode-yaml'
)

installed="$("$CODE" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
installed_count="$(printf '%s' "$installed" | grep -c . || true)"

has_ext() { printf '%s\n' "$installed" | grep -qx "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; }

# Todo-Tree only works when we found a ripgrep to hand it
if [ -n "$RG" ]; then
  extensions+=('gruntfuggly.todo-tree')
elif has_ext 'gruntfuggly.todo-tree'; then
  bad "Removing todo-tree (no ripgrep available)"
  "$CODE" --uninstall-extension gruntfuggly.todo-tree >/dev/null 2>&1
fi

missing=()
for ext in "${extensions[@]}"; do
  has_ext "$ext" || missing+=("$ext")
done
ok "$installed_count already installed, ${#missing[@]} to add"

failed=()
i=0
if [ "${#missing[@]}" -gt 0 ]; then
  for ext in "${missing[@]}"; do
    i=$((i + 1))
    printf '   [%2d/%d] %s' "$i" "${#missing[@]}" "$ext"
    if out="$("$CODE" --install-extension "$ext" --force 2>&1)"; then
      printf '  %sok%s\n' "$C_GREEN" "$C_OFF"
    else
      printf '  %sFAILED%s\n' "$C_RED" "$C_OFF"
      printf '        %s%s%s\n' "$C_DIM" "$(printf '%s' "$out" | tr '\n' '|')" "$C_OFF"
      failed+=("$ext")
    fi
  done
fi

if [ "${#failed[@]}" -eq 0 ]; then
  ok "Extensions up to date"
else
  bad "${#failed[@]} failed: ${failed[*]}"
fi

printf '\n=====================================================\n'
printf ' DONE - quit VS Code completely (Cmd+Q), then reopen it.\n'
printf '=====================================================\n'

finish 0
