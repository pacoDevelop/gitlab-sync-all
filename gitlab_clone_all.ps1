# ---------------------------
# Script to clone or update repositories from a GitLab group (internationalizable)
# Optimized version with console arguments and debug logs
# ---------------------------

param(
    [string]$Lang,                # Forced language (e.g., es, en, fr...)
    [string]$Hostname = "your-gitlab-server.com",  # TODO: Replace with your GitLab hostname
    [string]$Group = "your-group/your-project",    # TODO: Replace with your group/project
    [string]$Token = "YOUR_GITLAB_TOKEN_HERE",     # TODO: Replace with your GitLab personal token
    [switch]$Debug                 # Enable debug logs
)

# ---------------------------
# Load translations from JSON
# ---------------------------
$translationsFile = Join-Path $PSScriptRoot "i18n.json"
if (-not (Test-Path $translationsFile)) {
    Write-Error "Translation file not found: $translationsFile"
    exit 1
}

$translations = Get-Content $translationsFile -Raw -Encoding UTF8 | ConvertFrom-Json

# Detect system language if not passed
if (-not $Lang) {
    $culture = (Get-Culture).TwoLetterISOLanguageName
    if ($translations.PSObject.Properties.Name -contains $culture) {
        $Lang = $culture
    } else {
        $Lang = "es"
        Write-Host "System language ($culture) not available. Using Spanish (es)."
    }
}

Write-Host ("Selected language: {0}" -f $Lang)

$T = $translations.$Lang

# ---------------------------
# Translation function
# ---------------------------
function T {
    param(
        [string]$key,
        [object]$arg = $null
    )

    $value = [string]($T.PSObject.Properties[$key].Value)

    if ($Debug) { Write-Host "DEBUG: key='$key', value='$value', arg=$arg" }

    if ($arg -ne $null) {
        return [string]::Format($value, @($arg))
    } else {
        return $value
    }
}



# ---------------------------
# Check glab.exe
# ---------------------------
$localGlab = Join-Path $PSScriptRoot "glab.exe"

if (-Not (Test-Path $localGlab)) {
    Write-Host (T "glab_not_found")
    $query = @"
{
  "query": "query { project(fullPath: \"gitlab-org/cli\") { releases(first: 1, sort: RELEASED_AT_DESC) { nodes { tagName assets { links { nodes { name directAssetUrl } } } } } } }",
  "variables": {}
}
"@

    try {
        $response = Invoke-RestMethod -Uri "https://gitlab.com/api/graphql" -Method Post -Headers @{ "Content-Type" = "application/json" } -Body $query

        $latestTag = $response.data.project.releases.nodes[0].tagName
        $exeUrl = $response.data.project.releases.nodes[0].assets.links.nodes |
                  Where-Object { $_.name -eq "glab.exe" } |
                  Select-Object -ExpandProperty directAssetUrl

        if ($exeUrl) {
            Write-Host (T "downloading" @($latestTag, $exeUrl))
            Invoke-WebRequest -Uri $exeUrl -OutFile $localGlab

            if (Test-Path $localGlab) {
                Write-Host (T "download_ok" @($latestTag))
            } else {
                Write-Host (T "download_fail")
                exit 1
            }
        } else {
            Write-Host (T "asset_not_found")
            exit 1
        }
    } catch {
        Write-Host (T "error_fetch" @($_))
        exit 1
    }
} else {
    Write-Host (T "found_local")
}

$glabCmd = $localGlab

# ---------------------------
# Default values
# ---------------------------
$escapedHostname = [Regex]::Escape($Hostname)
$REGEXGITLAB = "^https://$escapedHostname/"
$REGEXGITLABSSH = "${escapedHostname}:"

Write-Host (T "defaults")
Write-Host ("Hostname: {0}" -f $Hostname)
Write-Host ("Group/Project: {0}" -f $Group)
Write-Host "Token: (hidden for security)"

# ---------------------------
# Environment setup
# ---------------------------
$env:GIT_SSL_NO_VERIFY = "true"
git config --global core.longpaths true

# ---------------------------
# Authentication
# ---------------------------
Write-Host (T "authenticating" @($Hostname))
& $glabCmd auth login --hostname $Hostname --token $Token
if ($LASTEXITCODE -ne 0) {
    Write-Host (T "auth_error")
    exit 1
}

# ---------------------------
# Helper functions
# ---------------------------
$repoBase = Get-Location

function Get-GroupProjects {
    param ([string]$groupPath)
    $projects = @()
    $page = 1
    $perPage = 100
    $encodedGroupPath = [uri]::EscapeDataString($groupPath)
    do {
        $url = "https://$Hostname/api/v4/groups/$encodedGroupPath/projects?per_page=$perPage&page=$page&include_subgroups=true"
        $response = Invoke-RestMethod -Uri $url -Headers @{ "Private-Token" = $Token }
        if ($response) { $projects += $response; $page++ } else { break }
    } while ($response.Count -eq $perPage)
    if ($Debug) { Write-Host ("DEBUG: Retrieved {0} projects from group {1}" -f $projects.Count, $groupPath) }
    return $projects
}

function Get-DestPathFromUrl {
    param([string]$repoUrl)
    $parsed = $repoUrl -replace "$REGEXGITLAB", "" -replace "^ssh://git@", "" -replace "^git@", "" -replace "$REGEXGITLABSSH", ""
    $parts = $parsed -split "/"
    $repoName = $parts[-1] -replace "\.git$", ""
    $namespace = ($parts[0..($parts.Count-2)]) -join "\"
    $destPath = Join-Path -Path $repoBase -ChildPath (Join-Path $namespace $repoName)
    return $destPath
}

function Clone-WithGit {
    param([string]$repoUrl)
    $destPath = Get-DestPathFromUrl $repoUrl
    if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Force -Path $destPath | Out-Null }
    Push-Location $destPath
    Write-Host (T "repo_cloning_git" @($destPath))
    git clone $repoUrl $destPath
    Pop-Location
}

# ---------------------------
# Process repositories
# ---------------------------
$repos = Get-GroupProjects -groupPath $Group

foreach ($repo in $repos) {
    $repoName = $repo.path_with_namespace
    $fullPath = Get-DestPathFromUrl $repo.web_url

    if (Test-Path $fullPath) {
        Write-Host "`n" (T "repo_exists" @($repoName))
        Set-Location $fullPath
        git pull --recurse-submodules
    } else {
        Write-Host "`n" (T "repo_cloning" @($repoName))
        $repoUrl = $repo.web_url
        try {
            Write-Host (T "repo_cloning_glab" @($repoUrl))
            & $glabCmd repo clone $repoUrl --preserve-namespace --archived=false 2>$null
            if ($LASTEXITCODE -ne 0) { throw "glab failed with exitcode $LASTEXITCODE" }
        } catch {
            Write-Warning (T "repo_clone_fail")
            Clone-WithGit $repoUrl
        }
    }
}

Write-Host "`n" (T "done" @($repoBase))
