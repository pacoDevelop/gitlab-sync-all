# ---------------------------
# Script para clonar todos los repos de un grupo en GitLab privado usando glab.exe local
# Descarga automáticamente la última versión de glab.exe desde GitLab.com
# ---------------------------

# Ruta absoluta al ejecutable local
$localGlab = Join-Path $PSScriptRoot "glab.exe"

# Comprobar si glab.exe existe en el directorio actual
if (-Not (Test-Path $localGlab)) {
    Write-Host "glab.exe no encontrado en el directorio actual. Buscando la última versión..."

    # Query GraphQL para obtener la última release
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

# Alias para usar el glab local (ruta absoluta)
$glabCmd = $localGlab

# Pedir datos al usuario
$HOSTNAME = Read-Host "Introduce el hostname de tu GitLab (ej: your-gitlab-server.com)"
$HOSTNAME = $HOSTNAME.Trim(" ", ")")  # limpiar posibles espacios o paréntesis
$GROUP = Read-Host "Introduce el grupo/proyecto (ej: your-group/your-project)"
$TOKEN = Read-Host -AsSecureString "Introduce tu token personal de GitLab"

# Convertir token seguro a texto plano
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TOKEN)
$TOKEN_PLAINTEXT = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Autenticación
Write-Host "Autenticando en $HOSTNAME ..."
$env:GLAB_TOKEN = $TOKEN_PLAINTEXT
& $glabCmd auth login --hostname $HOSTNAME --token $TOKEN_PLAINTEXT

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error de autenticación. Revisa tu token o hostname."
    exit 1
}

# Crear carpeta de trabajo
$repoPath = Join-Path $PSScriptRoot "gitlab_repos"
if (-not (Test-Path $repoPath)) {
    New-Item -ItemType Directory -Path $repoPath | Out-Null
}
Set-Location $repoPath

# Clonar todos los repos
Write-Host "Clonando todos los repos de $GROUP ..."
& $glabCmd repo clone -g $GROUP --paginate --preserve-namespace --archived=false


Write-Host "Proceso completado. Los repos están en la carpeta gitlab_repos"
