# ---------------------------
# Script para clonar todos los repos de un grupo en GitLab privado usando glab.exe local
# Descarga automáticamente la última versión de glab.exe desde GitLab.com
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

Write-Host "Usando valores por defecto:"
Write-Host "Hostname: $HOSTNAME"
Write-Host "Grupo/Proyecto: $GROUP"
Write-Host "Token: (oculto por seguridad)"

# Desactivar verificación SSL temporalmente
$env:GIT_SSL_NO_VERIFY = "true"

# Autenticación
Write-Host "Autenticando en $HOSTNAME ..."
& $glabCmd auth login --hostname $HOSTNAME --token $TOKEN_PLAINTEXT 
git config --global core.longpaths true

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error de autenticación. Revisa tu token o hostname."
    exit 1
}

# Carpeta de repos
$repoPath = Join-Path $PSScriptRoot "gitlab_repos"
if (-not (Test-Path $repoPath)) {
    New-Item -ItemType Directory -Path $repoPath | Out-Null
}
Set-Location $repoPath

# Clonar todos los repos
Write-Host "Clonando todos los repos de $GROUP ..."
& $glabCmd repo clone -g $GROUP --paginate --preserve-namespace --archived=false

Write-Host "Proceso completado. Los repos están en la carpeta gitlab_repos"
