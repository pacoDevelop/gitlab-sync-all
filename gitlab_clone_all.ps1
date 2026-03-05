# ---------------------------
# Script para clonar o actualizar todos los repos de un grupo en GitLab privado usando glab.exe
# ---------------------------

$localGlab = Join-Path $PSScriptRoot "glab.exe"

# Comprobar glab.exe
if (-Not (Test-Path $localGlab)) {
    Write-Host "glab.exe no encontrado en el directorio actual."
    exit 1
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

# Configuración Git
git config --global core.longpaths true
$env:GIT_SSL_NO_VERIFY = "true"

# Autenticación
Write-Host "Autenticando en $HOSTNAME ..."
& $glabCmd auth login --hostname $HOSTNAME --token $TOKEN_PLAINTEXT 

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error de autenticación. Revisa tu token o hostname."
    exit 1
}

# Carpeta de repos
$repoPath = Join-Path $PSScriptRoot "gitlab_repos"
if (-not (Test-Path $repoPath)) { New-Item -ItemType Directory -Path $repoPath | Out-Null }
Set-Location $repoPath

# Obtener lista de repos del grupo
$repos = & $glabCmd repo list -g $GROUP -F json | ConvertFrom-Json

foreach ($repoName in $repos) {
    $fullPath = Join-Path $repoPath $repoName

    if (Test-Path (Join-Path $fullPath ".git")) {
        Write-Host "`nRepositorio '$repoName' ya existe. Haciendo git pull..."
        Set-Location $fullPath
        git pull
    } elseif (-Not (Test-Path $fullPath)) {
        Write-Host "`nClonando repositorio '$repoName'..."
        & $glabCmd repo clone $repoName --preserve-namespace --archived=false
    } else {
        Write-Host "`nLa carpeta '$fullPath' existe pero no es un repositorio Git. Ignorando."
    }
}

Write-Host "`nProceso completado. Los repos están en la carpeta gitlab_repos"
