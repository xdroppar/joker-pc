# Joker Poker Club for Windows: installs the game, keeps it up to date, and starts it.
#
# First time (paste into PowerShell):
#   irm https://github.com/xdroppar/joker-pc/releases/latest/download/install.ps1 | iex
#
# That puts the game in %LOCALAPPDATA%\Programs\Joker and a "Joker" shortcut on the desktop and in the Start Menu.
# The shortcut runs this same script, which checks the newest release first and only downloads when it changed,
# so new builds arrive on their own. Offline, or if GitHub doesn't answer, the installed game just starts.
#
# Test switches (environment): JOKER_DIR = install somewhere else, JOKER_NO_LAUNCH = 1 to skip starting the game,
# JOKER_NO_SHORTCUTS = 1 to leave the desktop alone.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'xdroppar/joker-pc'
$dir = if ($env:JOKER_DIR) { $env:JOKER_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\Joker' }
$versionFile = Join-Path $dir 'version.txt'
$exe = Join-Path $dir 'Joker.exe'
New-Item -ItemType Directory -Force $dir | Out-Null

function Say($text) { Write-Host "[Joker] $text" }

try {
    $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'joker-installer' }
    $asset = $release.assets | Where-Object { $_.name -eq 'Joker-PC.zip' } | Select-Object -First 1
    $have = if (Test-Path $versionFile) { (Get-Content $versionFile -TotalCount 1).Trim() } else { '' }
    $running = Get-Process Joker -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$dir*" }

    if ($asset -and $release.tag_name -ne $have -and -not $running) {
        # The shortcut starts this hidden; a download needs a window, or the click looks like it did nothing.
        if ($args -contains 'hidden') {
            Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
            return
        }
        $gb = [math]::Round($asset.size / 1GB, 1)
        Say "Downloading $($release.tag_name) ($gb GB). This takes a few minutes the first time..."
        $tmp = Join-Path $env:TEMP "joker-$($release.tag_name)"
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $zip = Join-Path $tmp 'Joker-PC.zip'
        # curl.exe ships with Windows 10+ and is far faster than Invoke-WebRequest for a big file.
        & curl.exe -L --fail --retry 3 -o $zip $asset.browser_download_url
        if ($LASTEXITCODE -ne 0 -or (Get-Item $zip).Length -ne $asset.size) { throw "download incomplete" }
        Say 'Unpacking...'
        & tar.exe -x -f $zip -C $tmp
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $tmp 'Joker\Joker.exe'))) { throw "unpack failed" }
        robocopy (Join-Path $tmp 'Joker') $dir /MIR /XF version.txt Joker-Launch.ps1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "copy failed ($LASTEXITCODE)" }
        Set-Content -Path $versionFile -Value $release.tag_name -Encoding ascii
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        Say "Installed $($release.tag_name)."
    }

    # Keep a copy of this script beside the game so the shortcut can update on every start.
    $launcher = Join-Path $dir 'Joker-Launch.ps1'
    $self = $release.assets | Where-Object { $_.name -eq 'install.ps1' } | Select-Object -First 1
    if ($self) { & curl.exe -sL --fail -o $launcher $self.browser_download_url | Out-Null }
} catch {
    Say "Couldn't check for an update ($($_.Exception.Message))."
}

if (-not (Test-Path $exe)) { Say 'The game is not installed yet. Check your internet connection and run this again.'; return }

if (-not $env:JOKER_NO_SHORTCUTS -and (Test-Path (Join-Path $dir 'Joker-Launch.ps1'))) {
    $shell = New-Object -ComObject WScript.Shell
    $places = @([Environment]::GetFolderPath('Desktop'), (Join-Path ([Environment]::GetFolderPath('Programs')) ''))
    foreach ($place in $places) {
        $link = $shell.CreateShortcut((Join-Path $place 'Joker.lnk'))
        $link.TargetPath = 'powershell.exe'
        $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $dir 'Joker-Launch.ps1')`" hidden"
        $link.WorkingDirectory = $dir
        $link.IconLocation = "$exe,0"
        $link.Save()
    }
}

if (-not $env:JOKER_NO_LAUNCH) { Start-Process -FilePath $exe -WorkingDirectory $dir }
