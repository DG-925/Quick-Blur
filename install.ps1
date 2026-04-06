param(
    [string]$VencordPath,
    [switch]$WatchBuild,
    [switch]$SkipBuild
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginFolderName = "quickBlur"
$pluginDisplayName = "QuickBlur"
$sourceFiles = @(
    "index.tsx",
    "styles.css"
)

foreach ($sourceFile in $sourceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $sourceFile) -PathType Leaf)) {
        throw "Could not find $sourceFile next to install.ps1."
    }
}

function Test-VencordCheckout {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $packageJsonPath = Join-Path $Path "package.json"
    $pluginsPath = Join-Path $Path "src\plugins"
    $buildScriptPath = Join-Path $Path "scripts\build\build.mjs"

    if (
        -not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $pluginsPath -PathType Container) -or
        -not (Test-Path -LiteralPath $buildScriptPath -PathType Leaf)
    ) {
        return $false
    }

    try {
        $packageJson = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
    } catch {
        return $false
    }

    return $packageJson.name -eq "vencord"
}

function Add-UniquePath {
    param(
        [System.Collections.ArrayList]$List,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    } catch {
        return
    }

    if (-not $List.Contains($resolved)) {
        [void]$List.Add($resolved)
    }
}

function Find-VencordAncestor {
    param(
        [string]$StartPath
    )

    if ([string]::IsNullOrWhiteSpace($StartPath)) {
        return $null
    }

    try {
        $current = Get-Item -LiteralPath $StartPath -ErrorAction Stop
    } catch {
        return $null
    }

    while ($current) {
        if (Test-VencordCheckout $current.FullName) {
            return $current.FullName
        }

        $current = $current.Parent
    }

    return $null
}

function Get-VencordCandidatesFromRoot {
    param(
        [string]$Root,
        [int]$MaxDepth = 1
    )

    $results = New-Object System.Collections.ArrayList

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $results
    }

    $queue = New-Object System.Collections.Queue
    $queue.Enqueue([pscustomobject]@{
            Path  = (Resolve-Path -LiteralPath $Root).Path
            Depth = 0
        })

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()

        if (Test-VencordCheckout $current.Path) {
            Add-UniquePath -List $results -Path $current.Path
        }

        if ($current.Depth -ge $MaxDepth) {
            continue
        }

        Get-ChildItem -LiteralPath $current.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $queue.Enqueue([pscustomobject]@{
                    Path  = $_.FullName
                    Depth = $current.Depth + 1
                })
        }
    }

    return $results
}

function Get-VencordScore {
    param(
        [string]$Path
    )

    $leaf = (Split-Path -Leaf $Path).ToLowerInvariant()
    $score = 0

    switch -Regex ($leaf) {
        "^vencord$" { $score += 100; break }
        "^vencord-build$" { $score += 95; break }
        "^vencord-src$" { $score += 90; break }
        "vencord" { $score += 75; break }
    }

    if (Test-Path -LiteralPath (Join-Path $Path "src\userplugins\$pluginFolderName")) {
        $score += 40
    }

    if (Test-Path -LiteralPath (Join-Path $Path ".git")) {
        $score += 20
    }

    if (Test-Path -LiteralPath (Join-Path $Path "dist")) {
        $score += 10
    }

    if ($env:USERPROFILE -and $Path.StartsWith($env:USERPROFILE, [System.StringComparison]::OrdinalIgnoreCase)) {
        $score += 5
    }

    return $score
}

function Resolve-VencordPath {
    param(
        [string]$InputPath
    )

    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $ancestor = Find-VencordAncestor $InputPath

        if ($ancestor) {
            return $ancestor
        }

        throw "Could not find a Vencord source checkout at or above $InputPath."
    }

    $ancestorMatches = New-Object System.Collections.ArrayList
    Add-UniquePath -List $ancestorMatches -Path (Find-VencordAncestor $repoRoot)
    Add-UniquePath -List $ancestorMatches -Path (Find-VencordAncestor (Get-Location).Path)

    if ($ancestorMatches.Count -gt 0) {
        return $ancestorMatches[0]
    }

    $searchRoots = New-Object System.Collections.ArrayList
    Add-UniquePath -List $searchRoots -Path $repoRoot
    Add-UniquePath -List $searchRoots -Path (Split-Path -Parent $repoRoot)
    Add-UniquePath -List $searchRoots -Path (Split-Path -Parent (Split-Path -Parent $repoRoot))
    Add-UniquePath -List $searchRoots -Path (Get-Location).Path
    Add-UniquePath -List $searchRoots -Path $env:USERPROFILE
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "Desktop")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "Documents")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "Downloads")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "source")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "source\repos")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "dev")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "code")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "projects")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "github")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "OneDrive")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "OneDrive\Desktop")
    Add-UniquePath -List $searchRoots -Path (Join-Path $env:USERPROFILE "OneDrive\Documents")

    $nearbyRoots = @(
        (Resolve-Path -LiteralPath $repoRoot -ErrorAction SilentlyContinue).Path,
        (Resolve-Path -LiteralPath (Split-Path -Parent $repoRoot) -ErrorAction SilentlyContinue).Path,
        (Resolve-Path -LiteralPath (Split-Path -Parent (Split-Path -Parent $repoRoot)) -ErrorAction SilentlyContinue).Path
    ) | Where-Object { $_ }

    $candidates = New-Object System.Collections.ArrayList

    foreach ($root in $searchRoots) {
        $depth = 1

        if ($nearbyRoots -contains $root) {
            $depth = 2
        }

        Get-VencordCandidatesFromRoot -Root $root -MaxDepth $depth | ForEach-Object {
            Add-UniquePath -List $candidates -Path $_
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    }

    $rankedCandidates = $candidates | ForEach-Object {
        [pscustomobject]@{
            Path  = $_
            Score = Get-VencordScore $_
        }
    } | Sort-Object @{ Expression = "Score"; Descending = $true }, @{ Expression = { $_.Path.Length }; Descending = $false }

    if ($rankedCandidates.Count -gt 1) {
        Write-Host "Found multiple Vencord source folders. Using the best match:"
        Write-Host $rankedCandidates[0].Path
        Write-Host ""
    }

    return $rankedCandidates[0].Path
}

function Get-BuildRunner {
    $pnpmCommand = Get-Command pnpm.cmd, pnpm -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($pnpmCommand) {
        return [pscustomobject]@{
            FilePath = $pnpmCommand.Source
            Args     = @()
            Display  = "pnpm"
        }
    }

    $corepackCommand = Get-Command corepack.cmd, corepack -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($corepackCommand) {
        return [pscustomobject]@{
            FilePath = $corepackCommand.Source
            Args     = @("pnpm")
            Display  = "corepack pnpm"
        }
    }

    return $null
}

function Invoke-VencordPnpmCommand {
    param(
        [string]$Path,
        [string[]]$Arguments,
        [string]$ActionName
    )

    $runner = Get-BuildRunner

    if (-not $runner) {
        throw "Node.js with Corepack is required to $ActionName Vencord."
    }

    Push-Location $Path
    try {
        & $runner.FilePath @($runner.Args + $Arguments) | Out-Host
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "Failed to $ActionName Vencord."
    }
}

function Get-BootstrapTargetPath {
    $basePath = Join-Path $env:USERPROFILE "Vencord-plugin-build"
    $candidatePath = $basePath
    $index = 2

    while (Test-Path -LiteralPath $candidatePath) {
        if (Test-VencordCheckout $candidatePath) {
            return $candidatePath
        }

        $hasContent = @(Get-ChildItem -LiteralPath $candidatePath -Force -ErrorAction SilentlyContinue).Count -gt 0

        if (-not $hasContent) {
            return $candidatePath
        }

        $candidatePath = "$basePath-$index"
        $index++
    }

    return $candidatePath
}

function Bootstrap-VencordCheckout {
    param(
        [string]$TargetPath
    )

    $nodeCommand = Get-Command node.exe, node -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $nodeCommand) {
        throw "Node.js is required to automatically set up Vencord. Install Node.js first, then run install.bat again."
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("quick-blur-" + [guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempRoot "vencord.zip"
    $extractPath = Join-Path $tempRoot "extract"

    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractPath | Out-Null

    try {
        Write-Host ""
        Write-Host "No Vencord source folder was found."
        Write-Host "Downloading a Vencord source checkout automatically..."

        Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/Vendicated/Vencord/archive/refs/heads/main.zip" -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $sourceRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Select-Object -First 1

        if (-not $sourceRoot) {
            throw "Downloaded Vencord archive, but could not find the extracted source folder."
        }

        New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
        Get-ChildItem -LiteralPath $sourceRoot.FullName -Force | Copy-Item -Destination $TargetPath -Recurse -Force

        Ensure-VencordDependencies -Path $TargetPath

        return $TargetPath
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-VencordDependencies {
    param(
        [string]$Path
    )

    if (Test-Path -LiteralPath (Join-Path $Path "node_modules") -PathType Container) {
        return
    }

    Write-Host ""
    Write-Host "Installing Vencord dependencies automatically..."
    Invoke-VencordPnpmCommand -Path $Path -Arguments @("install", "--frozen-lockfile") -ActionName "install dependencies for"
}

function Get-DiscordInstallCandidates {
    $candidates = New-Object System.Collections.ArrayList

    Add-UniquePath -List $candidates -Path (Join-Path $env:LOCALAPPDATA "Discord")
    Add-UniquePath -List $candidates -Path (Join-Path $env:LOCALAPPDATA "DiscordPTB")
    Add-UniquePath -List $candidates -Path (Join-Path $env:LOCALAPPDATA "DiscordCanary")

    return $candidates
}

function Resolve-DiscordInstallPath {
    foreach ($candidate in Get-DiscordInstallCandidates) {
        $appFolder = Get-ChildItem -LiteralPath $candidate -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "app-*" } |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if ($appFolder) {
            return $candidate
        }
    }

    return $null
}

function Stop-DiscordProcessesForInstallRoot {
    param(
        [string]$InstallRoot
    )

    if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
        return
    }

    $normalizedRoot = $InstallRoot.TrimEnd("\")
    $runningDiscord = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like "Discord*"
    }

    if (-not $runningDiscord) {
        return
    }

    $matchingProcesses = @($runningDiscord | Where-Object {
            $_.Path -and $_.Path.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)
        })

    if ($matchingProcesses.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "Closing Discord so Vencord can be installed cleanly..."
    $matchingProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Run-VencordBuild {
    param(
        [string]$Path,
        [switch]$Watch
    )

    $runner = Get-BuildRunner

    if (-not $runner) {
        throw "Node.js with Corepack is required to build Vencord."
    }

    $gitMetadataNeeded = -not (Test-Path -LiteralPath (Join-Path $Path ".git"))
    $oldHash = $env:VENCORD_HASH
    $oldRemote = $env:VENCORD_REMOTE

    if ($gitMetadataNeeded) {
        if ([string]::IsNullOrWhiteSpace($env:VENCORD_HASH)) {
            $env:VENCORD_HASH = "custom"
        }

        if ([string]::IsNullOrWhiteSpace($env:VENCORD_REMOTE)) {
            $env:VENCORD_REMOTE = "Vendicated/Vencord"
        }
    }

    if ($Watch) {
        $commandText = ((@($runner.Display) + @("build", "--watch")) -join " ")

        if ($gitMetadataNeeded) {
            $commandText = '$env:VENCORD_HASH="' + $env:VENCORD_HASH + '"; $env:VENCORD_REMOTE="' + $env:VENCORD_REMOTE + '"; ' + $commandText
        }

        Write-Host ""
        Write-Host "Starting Vencord watch build in a new window..."
        Start-Process powershell -WorkingDirectory $Path -ArgumentList @(
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            $commandText
        ) | Out-Null

        if ($gitMetadataNeeded) {
            if ($null -eq $oldHash) { Remove-Item Env:VENCORD_HASH -ErrorAction SilentlyContinue } else { $env:VENCORD_HASH = $oldHash }
            if ($null -eq $oldRemote) { Remove-Item Env:VENCORD_REMOTE -ErrorAction SilentlyContinue } else { $env:VENCORD_REMOTE = $oldRemote }
        }

        return
    }

    Write-Host ""
    Write-Host "Building Vencord automatically..."

    Push-Location $Path
    try {
        & $runner.FilePath @($runner.Args + @("build")) | Out-Host
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location

        if ($gitMetadataNeeded) {
            if ($null -eq $oldHash) { Remove-Item Env:VENCORD_HASH -ErrorAction SilentlyContinue } else { $env:VENCORD_HASH = $oldHash }
            if ($null -eq $oldRemote) { Remove-Item Env:VENCORD_REMOTE -ErrorAction SilentlyContinue } else { $env:VENCORD_REMOTE = $oldRemote }
        }
    }

    if ($exitCode -ne 0) {
        throw "Vencord build failed. Open $Path and run '$($runner.Display) build' manually to see the error."
    }
}

function Install-VencordIntoDiscord {
    param(
        [string]$SourceCheckoutPath,
        [string]$DiscordInstallPath
    )

    $nodeCommand = Get-Command node.exe, node -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $nodeCommand) {
        throw "Node.js is required to run the Vencord installer CLI."
    }

    if ($DiscordInstallPath) {
        Stop-DiscordProcessesForInstallRoot $DiscordInstallPath
    }

    $installerArgs = @(
        "scripts/runInstaller.mjs",
        "--",
        "--install"
    )

    if ($DiscordInstallPath) {
        $installerArgs += @("--location", $DiscordInstallPath)
    } else {
        $installerArgs += @("--branch", "auto")
    }

    Write-Host ""
    Write-Host "Downloading or updating the Vencord installer CLI automatically..."
    Write-Host "Installing Vencord into Discord..."

    Push-Location $SourceCheckoutPath
    try {
        & $nodeCommand.Source @installerArgs | Out-Host
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "Failed to install Vencord into Discord automatically."
    }
}

$resolvedVencordPath = Resolve-VencordPath $VencordPath
$bootstrappedVencord = $false
$resolvedDiscordInstallPath = Resolve-DiscordInstallPath

if (-not $resolvedVencordPath) {
    $resolvedVencordPath = Bootstrap-VencordCheckout -TargetPath (Get-BootstrapTargetPath)
    $bootstrappedVencord = $true
}

if (-not $resolvedVencordPath) {
    throw "Could not find or create a Vencord source checkout."
}

$srcPath = Join-Path $resolvedVencordPath "src"
$userPluginsPath = Join-Path $srcPath "userplugins"
$targetFolder = Join-Path $userPluginsPath $pluginFolderName

New-Item -ItemType Directory -Force -Path $userPluginsPath | Out-Null
New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null

foreach ($sourceFile in $sourceFiles) {
    Copy-Item -LiteralPath (Join-Path $repoRoot $sourceFile) -Destination (Join-Path $targetFolder $sourceFile) -Force
}

if (-not $SkipBuild) {
    Ensure-VencordDependencies -Path $resolvedVencordPath
    Run-VencordBuild -Path $resolvedVencordPath -Watch:$WatchBuild

    if (-not $WatchBuild) {
        Install-VencordIntoDiscord -SourceCheckoutPath $resolvedVencordPath -DiscordInstallPath $resolvedDiscordInstallPath
    }
}

Write-Host ""
Write-Host "Installed $pluginDisplayName to:"
Write-Host $targetFolder
Write-Host ""
Write-Host "Vencord folder:"
Write-Host $resolvedVencordPath
Write-Host ""
if ($resolvedDiscordInstallPath) {
    Write-Host "Discord install:"
    Write-Host $resolvedDiscordInstallPath
    Write-Host ""
}
Write-Host "Next steps:"
if ($SkipBuild) {
    Write-Host "1. Run 'corepack pnpm build' in the Vencord folder"
    Write-Host "2. Run 'node scripts/runInstaller.mjs -- --install --branch auto' in the Vencord folder"
    Write-Host "3. Open Discord and enable $pluginDisplayName in Vencord settings"
} elseif ($WatchBuild) {
    Write-Host "1. Let the new build window finish"
    Write-Host "2. Run 'node scripts/runInstaller.mjs -- --install --branch auto' in the Vencord folder if Discord was not patched yet"
    Write-Host "3. Open Discord and enable $pluginDisplayName in Vencord settings"
} else {
    Write-Host "1. Open Discord again"
    Write-Host "2. Enable $pluginDisplayName in Vencord settings"
}

if ($bootstrappedVencord) {
    Write-Host ""
    Write-Host "A fresh Vencord source checkout was created automatically for this install."
}
