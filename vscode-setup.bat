@echo off
setlocal
chcp 65001 >nul
title VS Code Pro Setup
set "SETUP_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$m='#:PS'+'_BEGIN';$s=[IO.File]::ReadAllText('%~f0');iex $s.Substring($s.IndexOf($m)+$m.Length)"
echo.
echo ---------------------------------------------
echo  Finished. Exit code: %ERRORLEVEL%
echo ---------------------------------------------
pause
exit /b
#:PS_BEGIN
# =====================================================================
#  VS Code "Pro" Setup - single-file installer
#    1. writes settings.json
#    2. installs JetBrains Mono (per-user, no admin)
#    3. installs the extension set (skips ones already present)
#    4. points Todo-Tree at VS Code's bundled ripgrep
#    5. deletes the leftover setup files
#  Safe to re-run. Log: vscode-setup-log.txt next to this file.
# =====================================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$here = $env:SETUP_DIR
if (-not $here) { $here = (Get-Location).Path }
$here = $here.TrimEnd('\')

Start-Transcript -Path (Join-Path $here 'vscode-setup-log.txt') -Force | Out-Null

function Step($m) { Write-Host "`n>> $m"        -ForegroundColor Cyan }
function Ok($m)   { Write-Host "   [ok]   $m"   -ForegroundColor Green }
function Bad($m)  { Write-Host "   [warn] $m"   -ForegroundColor Yellow }

Write-Host "PowerShell : $($PSVersionTable.PSVersion)"
Write-Host "Folder     : $here"

try {

# ---------------------------------------------------------------------
# 1) Locate the VS Code CLI
# ---------------------------------------------------------------------
Step "Locating VS Code"
$code = (Get-Command code -ErrorAction SilentlyContinue).Source
$roots = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
    "$env:ProgramFiles\Microsoft VS Code",
    "${env:ProgramFiles(x86)}\Microsoft VS Code"
) | Where-Object { Test-Path $_ }

if (-not $code) {
    foreach ($r in $roots) {
        $c = Join-Path $r 'bin\code.cmd'
        if (Test-Path $c) { $code = $c; break }
    }
}
if (-not $code) {
    Bad "Could not find the 'code' command."
    Bad "Open VS Code -> Ctrl+Shift+P -> 'Shell Command: Install code command in PATH', then re-run."
    Stop-Transcript | Out-Null
    exit 1
}
Ok "CLI: $code"

# ---------------------------------------------------------------------
# 2) Find VS Code's bundled ripgrep (Todo-Tree needs an explicit path)
# ---------------------------------------------------------------------
Step "Looking for bundled ripgrep"
$rg = $null
foreach ($r in $roots) {
    $res = Join-Path $r 'resources'
    if (-not (Test-Path $res)) { continue }
    $hit = Get-ChildItem -Path $res -Filter 'rg.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { $rg = $hit.FullName; break }
}
if ($rg) { Ok "ripgrep: $rg" } else { Bad "Not found - Todo-Tree will be skipped" }

# ---------------------------------------------------------------------
# 3) Write settings.json
# ---------------------------------------------------------------------
Step "Writing settings.json"

$settingsPath = "$env:APPDATA\Code\User\settings.json"
New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null

$settings = @'
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
  "editor.fontFamily": "'JetBrains Mono', 'Cascadia Code', Consolas, 'Courier New', monospace",
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
  "terminal.integrated.fontFamily": "'JetBrains Mono', 'Cascadia Mono', Consolas, monospace",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.lineHeight": 1.3,
  "terminal.integrated.cursorBlinking": true,
  "terminal.integrated.cursorStyle": "line",
  "terminal.integrated.smoothScrolling": true,
  "terminal.integrated.defaultProfile.windows": "PowerShell",
  "terminal.integrated.scrollback": 10000,
  "terminal.integrated.gpuAcceleration": "on",

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
'@

if ($rg) {
    $escaped = $rg -replace '\\', '\\'
    $idx = $settings.IndexOf('{')
    $settings = $settings.Substring(0, $idx + 1) + "`r`n" +
                '  "todo-tree.ripgrep": "' + $escaped + '",' +
                $settings.Substring($idx + 1)
}

if (Test-Path $settingsPath) {
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    Ok "Backed up old settings -> settings.json.bak"
}
[IO.File]::WriteAllText($settingsPath, $settings, (New-Object Text.UTF8Encoding $false))
Ok "Wrote $settingsPath"

# ---------------------------------------------------------------------
# 4) JetBrains Mono (per-user install, no admin)
# ---------------------------------------------------------------------
Step "JetBrains Mono font"

$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

$already = @(Get-ChildItem $fontDir -Filter "JetBrainsMono*.ttf" -ErrorAction SilentlyContinue)
if ($already.Count -ge 4) {
    Ok "Already installed ($($already.Count) files) - skipping"
} else {
    $tmp = Join-Path $env:TEMP "jbmono"
    $zip = Join-Path $env:TEMP "JetBrainsMono.zip"
    $url = "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "   downloading..."
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        $ttfs = @(Get-ChildItem $tmp -Recurse -Filter "*.ttf" | Where-Object { $_.FullName -match '\\ttf\\' })
        if ($ttfs.Count -eq 0) { $ttfs = @(Get-ChildItem $tmp -Recurse -Filter "*.ttf") }

        foreach ($f in $ttfs) {
            $dest = Join-Path $fontDir $f.Name
            Copy-Item $f.FullName $dest -Force
            $name = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '-', ' '
            New-ItemProperty -Path $regPath -Name "$name (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        }
        Ok "Installed $($ttfs.Count) font files"
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Bad "Font download failed: $($_.Exception.Message)"
        Bad "Not fatal - VS Code falls back to Cascadia Code / Consolas."
    }
}

# ---------------------------------------------------------------------
# 5) Extensions (only the missing ones)
# ---------------------------------------------------------------------
Step "Extensions"

$extensions = [Collections.ArrayList]@(
    'catppuccin.catppuccin-vsc',
    'pkief.material-icon-theme',
    'pkief.material-product-icons',
    'usernamehw.errorlens',
    'eamodio.gitlens',
    'mhutchie.git-graph',
    'editorconfig.editorconfig',
    'aaron-bond.better-comments',
    'christian-kohler.path-intellisense',
    'streetsidesoftware.code-spell-checker',
    'ms-dotnettools.csharp',
    'ms-dotnettools.csdevkit',
    'ms-dotnettools.vscode-dotnet-runtime',
    'ms-python.python',
    'ms-python.vscode-pylance',
    'ms-python.debugpy',
    'charliermarsh.ruff',
    'ms-vscode.cpptools-extension-pack',
    'platformio.platformio-ide',
    'ms-vscode.hexeditor',
    'redhat.vscode-yaml'
)

$installed = @(@(& $code --list-extensions 2>$null) | ForEach-Object { $_.Trim().ToLower() })

# Todo-Tree only works when we found a ripgrep to hand it
if ($rg) {
    [void]$extensions.Add('gruntfuggly.todo-tree')
} elseif ($installed -contains 'gruntfuggly.todo-tree') {
    Bad "Removing todo-tree (no ripgrep available)"
    & $code --uninstall-extension gruntfuggly.todo-tree 2>&1 | Out-Null
}

$missing = @($extensions | Where-Object { $installed -notcontains $_.ToLower() })
Ok "$($installed.Count) already installed, $($missing.Count) to add"

$failed = @()
$i = 0
foreach ($ext in $missing) {
    $i++
    Write-Host ("   [{0,2}/{1}] {2}" -f $i, $missing.Count, $ext) -NoNewline
    $out = & $code --install-extension $ext --force 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED" -ForegroundColor Red
        Write-Host "        $($out -join ' | ')" -ForegroundColor DarkGray
        $failed += $ext
    } else {
        Write-Host "  ok" -ForegroundColor Green
    }
}
if ($failed.Count -eq 0) { Ok "Extensions up to date" }
else { Bad "$($failed.Count) failed: $($failed -join ', ')" }

# ---------------------------------------------------------------------
# 6) Clean up the old multi-file setup
# ---------------------------------------------------------------------
Step "Cleaning up old setup files"

$old = @(
    'vscode-pro-setup.bat', 'vscode-pro-setup.ps1',
    'setup.ps1',            'RUN-SETUP.bat',
    'fix-todotree.ps1',     'FIX-TODOTREE.bat',
    'setup-log.txt',        'fix-log.txt'
)
$removed = 0
foreach ($f in $old) {
    $p = Join-Path $here $f
    if (Test-Path $p) {
        try { Remove-Item $p -Force; Write-Host "   removed $f"; $removed++ }
        catch { Bad "could not remove $f : $($_.Exception.Message)" }
    }
}
Ok "$removed old file(s) removed"

Write-Host "`n====================================================="
Write-Host " DONE - close VS Code completely, then reopen it."
Write-Host "====================================================="

}
catch {
    Write-Host "`n!!! UNHANDLED ERROR !!!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}
finally {
    Stop-Transcript | Out-Null
}
