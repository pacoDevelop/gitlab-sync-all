# ---------------------------
# Script para clonar todos los repos de un grupo en GitLab usando glab.exe local
# ---------------------------

# Nombre del ejecutable local
$localGlab = ".\glab.exe"

# URL base para obtener la lista de releases
$releasesUrl = "https://gitlab.com/gitlab-org/cli/-/releases"

# Comprobar si glab.exe existe en el directorio actual
if (-Not (Test-Path $localGlab)) {
    Write-Host "glab.exe no encontrado en el directorio actual."

    # Obtener la última versión estable desde la página de releases
    $html = Invoke-WebRequest -Uri $releasesUrl
    $latestReleaseLink = ($html.Links | Where-Object { $_.href -match "glab-v(\d+\.\d+\.\d+)-windows-amd64.exe" })[0].href
    $version = $latestReleaseLink -replace ".*glab-v(\d+\.\d+\.\d+)-windows-amd64.exe", '$1'
    $downloadUrl = "https://gitlab.com$latestReleaseLink"

    Write-Host "Descargando glab.exe (v$version) desde $downloadUrl ..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$PSScriptRoot\glab.exe"

    # Verificar si glab.exe se descargó correctamente
    if (Test-Path $localGlab) {
        Write-Host "glab.exe (v$version) descargado correctamente."
    } else {
        Write-Host "No se pudo descargar glab.exe. Revisa tu conexión o permisos."
        exit 1
    }
} else {
    Write-Host "Se encontró glab.exe en el directorio actual."
}

# Alias para usar el glab local
$glabCmd = $localGlab

# Pedir datos al usuario
$HOSTNAME = Read-Host "Introduce el hostname de tu GitLab (ej: your-gitlab-server.com)"
$GROUP = Read-Host "Introduce el grupo/proyecto (ej: your-group/your-project)"
$TOKEN = Read-Host -AsSecureString "Introduce tu token personal de GitLab"

# Convertir token seguro a texto plano
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TOKEN)
$TOKEN_PLAINTEXT = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Autenticación
Write-Host "Autenticando en $HOSTNAME ..."
& $glabCmd auth login --hostname $HOSTNAME --token $TOKEN_PLAINTEXT

# Crear carpeta de trabajo
$repoPath = "gitlab_repos"
if (-not (Test-Path $repoPath)) {
    New-Item -ItemType Directory -Path $repoPath | Out-Null
}
Set-Location $repoPath

# Clonar todos los repos
Write-Host "Clonando todos los repos de $GROUP ..."
& $glabCmd repo clone -g $GROUP --paginate --preserve-namespace --archived=false

Write-Host "Proceso completado. Los repos estan en la carpeta gitlab_repos"
