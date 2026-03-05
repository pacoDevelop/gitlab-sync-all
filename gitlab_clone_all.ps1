# ---------------------------
# Script para clonar o actualizar todos los repos de un grupo en GitLab privado usando glab.exe
# ---------------------------

$localGlab = Join-Path $PSScriptRoot "glab.exe"

# Comprobar glab.exe
if (-Not (Test-Path $localGlab)) {
    Write-Host "glab.exe no encontrado en el directorio actual. Buscando la última versión..."
    $query = @"
{
  "query": "query { project(fullPath: \"gitlab-org/cli\") { releases(first: 1, sort: RELEASED_AT_DESC) { nodes { tagName assets { links { nodes { name directAssetUrl } } } } } } }",
  "variables": {}
}
"@

    try {
        $response = Invoke-RestMethod -Uri "https://gitlab.com/api/graphql" `
            -Method Post `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $query

        $latestTag = $response.data.project.releases.nodes[0].tagName
        $exeUrl = $response.data.project.releases.nodes[0].assets.links.nodes |
            Where-Object { $_.name -eq "glab.exe" } |
            Select-Object -ExpandProperty directAssetUrl

        if ($exeUrl) {
            Write-Host "Descargando glab.exe ($latestTag) desde $exeUrl ..."
            Invoke-WebRequest -Uri $exeUrl -OutFile $localGlab

            if (Test-Path $localGlab) {
                Write-Host "glab.exe ($latestTag) descargado correctamente."
            } else {
                Write-Host "No se pudo descargar glab.exe. Revisa tu conexión o permisos."
                exit 1
            }
        } else {
            Write-Host "No se encontró el asset glab.exe en la última release."
            exit 1
        }
    } catch {
        Write-Host "Error al obtener la última versión de glab.exe: $_"
        exit 1
    }
} else {
    Write-Host "Se encontró glab.exe en el directorio actual."
}

$glabCmd = $localGlab

# Valores por defecto
$HOSTNAME = "your-gitlab-server.com"  # TODO: Replace with your GitLab hostname
$GROUP = "your-group/your-project"   # TODO: Replace with your group/project
$TOKEN_PLAINTEXT = "YOUR_GITLAB_TOKEN_HERE"  # TODO: Replace with your GitLab personal token
$escapedHostname = [Regex]::Escape($HOSTNAME)
$REGEXGITLAB = "^https://$escapedHostname/"
$REGEXGITLABSSH = "${escapedHostname}:"

Write-Host "Usando valores por defecto:"
Write-Host "Hostname: $HOSTNAME"
Write-Host "Grupo/Proyecto: $GROUP"
Write-Host "Token: (oculto por seguridad)"

# Desactivar verificación SSL temporalmente
$env:GIT_SSL_NO_VERIFY = "true"

# Activar rutas largas en Git
git config --global core.longpaths true

# Autenticación
Write-Host "Autenticando en $HOSTNAME ..."
& $glabCmd auth login --hostname $HOSTNAME --token $TOKEN_PLAINTEXT
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error de autenticación. Revisa tu token o hostname."
    exit 1
}

# Carpeta base de repos: donde estés ejecutando el script
$repoBase = Get-Location

# Función para obtener todos los repositorios de un grupo y sus subgrupos
function Get-GroupProjects {
    param ([string]$groupPath)
    $projects = @()
    $page = 1
    $perPage = 100
    $encodedGroupPath = [uri]::EscapeDataString($groupPath)
    do {
        $url = "https://$HOSTNAME/api/v4/groups/$encodedGroupPath/projects?per_page=$perPage&page=$page&include_subgroups=true"
        $response = Invoke-RestMethod -Uri $url -Headers @{ "Private-Token" = $TOKEN_PLAINTEXT }
        if ($response) { $projects += $response; $page++ } else { break }
    } while ($response.Count -eq $perPage)
    return $projects
}

# Función auxiliar: genera ruta segura de destino a partir de la URL
function Get-DestPathFromUrl {
    param([string]$repoUrl)
    $parsed = $repoUrl -replace "$REGEXGITLAB", "" -replace "^ssh://git@", "" -replace "^git@", "" -replace "$REGEXGITLABSSH", ""
    $parts = $parsed -split "/"
    $repoName = $parts[-1] -replace "\.git$", ""
    $namespace = ($parts[0..($parts.Count-2)]) -join "\"
    $destPath = Join-Path -Path $repoBase -ChildPath (Join-Path $namespace $repoName)
    return $destPath
}

# Función auxiliar: clona repo con git si falla glab
function Clone-WithGit {
    param([string]$repoUrl)
    $destPath = Get-DestPathFromUrl $repoUrl
    if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Force -Path $destPath | Out-Null }
    Push-Location $destPath
    Write-Host "Fallback a git clone en $destPath ..."
    git clone $repoUrl $destPath
    Pop-Location
}

# Obtener todos los repos
$repos = Get-GroupProjects -groupPath $GROUP

foreach ($repo in $repos) {
    $repoName = $repo.path_with_namespace
    $fullPath = Get-DestPathFromUrl $repo.web_url

    if (Test-Path $fullPath) {
        Write-Host "`nRepositorio '$repoName' ya existe. Haciendo git pull..."
        Set-Location $fullPath
        git pull --recurse-submodules
    } else {
        Write-Host "`nClonando repositorio '$repoName'..."
        $repoUrl = $repo.web_url
        try {
            Write-Host "Clonando con glab: $repoUrl"
            & $glabCmd repo clone $repoUrl --preserve-namespace --archived=false 2>$null
            if ($LASTEXITCODE -ne 0) { throw "glab fallo con exitcode $LASTEXITCODE" }
        } catch {
            Write-Warning "glab repo clone fallo, usando git clone en fallback..."
            Clone-WithGit $repoUrl
        }
    }
}

Write-Host "`nProceso completado. Los repos están en la carpeta $repoBase"
