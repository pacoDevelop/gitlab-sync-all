#gitlab-sync-all

GitLab Sync All es un script de PowerShell que automatiza la clonación y actualización de todos los repositorios de un grupo de GitLab, incluidos sus subgrupos. Detecta el idioma del sistema, admite múltiples idiomas mediante un archivo JSON, gestiona la autenticación con un personal access token, y garantiza que todos los repositorios estén actualizados utilizando git pull o git clone.
# Script para Clonar Todos los Repositorios de GitLab

**Requisitos previos importantes antes de usar el script:**

* **Instala tu certificado SSL** para evitar problemas de SSL. Descárgalo desde tu servidor GitLab a través del navegador e instálalo en tu PC.

* **Ejecuta el script una vez para crear las carpetas necesarias**. `glab` las generará automáticamente en la primera ejecución:

  ```
  D:\Users\tu_usuario\.config\glab-cli
  ```

* **Después de crear las carpetas, modifica la configuración** para apuntar a tu propio host GitLab y establece `git_protocol: https`.

---

## Descripción General

Este script PowerShell te permite **clonar o actualizar automáticamente todos los repositorios de un grupo específico de GitLab** (incluyendo subgrupos). Es internacionalizable y soporta múltiples idiomas a través de un archivo JSON de traducciones (`i18n.json`).

El script utiliza `glab.exe` (GitLab CLI) para clonar y se revierte a `git clone` si es necesario.

---

## Funcionalidades

* Detección automática del idioma del sistema o selección mediante el parámetro `-Lang`.
* Descarga automática de la versión más reciente de `glab.exe` si no está presente localmente.
* Maneja la autenticación con tu host GitLab mediante token de acceso personal.
* Procesa todos los repositorios de un grupo, incluyendo subgrupos.
* Ejecuta `git pull --recurse-submodules` si el repositorio ya existe.
* Fallback a `git clone` si `glab` falla.
* Modo depuración para rastrear la ejecución del script.
* Crea automáticamente carpetas de configuración necesarias en la primera ejecución.

---

## Requisitos

* PowerShell 5.1+ o PowerShell Core
* Git instalado y disponible en PATH
* Acceso a Internet para descargar `glab.exe` (a menos que ya esté presente)
* Token de acceso personal para tu host GitLab

## ⚠️ Advertencias de Seguridad

* **Nunca commits tu token de GitLab** en control de versiones. Pásalo como parámetro o a través de entrada segura.
* El token se almacena en texto plano en memoria durante la ejecución del script - úsalo solo en entornos seguros.
* El script desactiva la verificación SSL (`GIT_SSL_NO_VERIFY=true`) por conveniencia; úsalo solo detrás de cortafuegos confiables.
* No expongas tu token de acceso personal en scripts, logs o variables de entorno.

---

## Instalación

1. Clona o descarga este repositorio.

2. Coloca `gitlab_clone_all.ps1` e `i18n.json` en el mismo directorio.

3. Asegúrate de que tu política de ejecución de PowerShell permite la ejecución de scripts:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

4. Descarga e instala los certificados SSL de tu servidor GitLab si es necesario (para evitar problemas de verificación SSL).

---

## Uso

Uso básico:

```powershell
.\gitlab_clone_all.ps1 -Hostname "gitlab.ejemplo.com" -Group "migrupo/subgrupo" -Token "tu_token_personal"
```

Forzar un idioma (por ejemplo, Inglés):

```powershell
.\gitlab_clone_all.ps1 -Lang en
```

Activar logs de depuración:

```powershell
.\gitlab_clone_all.ps1 -Debug
```

### Parámetros

| Parámetro    | Descripción                                                    |
| ------------ | -------------------------------------------------------------- |
| `-Lang`      | Fuerza el idioma de los mensajes (por defecto: idioma del sistema) |
| `-Hostname`  | Host de GitLab (por defecto: your-gitlab-server.com)          |
| `-Group`     | Ruta del grupo de GitLab (por defecto: your-group/your-project) |
| `-Token`     | Token de acceso personal para autenticación                    |
| `-Debug`     | Activa el registro de depuración                               |

---

## Cómo Funciona

1. Carga las traducciones desde `i18n.json`.

2. Detecta el idioma (o usa el idioma forzado).

3. Comprueba si `glab.exe` existe; si no, descarga la última versión.

4. Se autentica con tu host GitLab usando el token proporcionado.

5. Obtiene todos los proyectos del grupo (incluyendo subgrupos) usando la API de GitLab.

6. Para cada repositorio:

   * Si ya está clonado, ejecuta `git pull --recurse-submodules`.
   * Si no está clonado, intenta `glab repo clone`.
   * Si `glab` falla, revierte a `git clone`.

7. Imprime el mensaje de finalización con la ruta base del repositorio.

---

## Ejemplo de Salida

```text
Idioma seleccionado: es
Usando valores por defecto:
Hostname: gitlab.ejemplo.com
Grupo/Proyecto: migrupo/subgrupo
Token: (oculto)
Autenticando en gitlab.ejemplo.com ...
Repositorio 'migrupo/repo1' ya existe. Desplegando cambios...
Clonando repositorio 'migrupo/repo2' ...
Clonando con glab: https://gitlab.ejemplo.com/migrupo/repo2.git
Proceso completado. Los repositorios están ubicados en C:\Users\usuario\repos
```

---

## Traducciones

* El script soporta múltiples idiomas a través de `i18n.json`.
* Idiomas soportados por defecto: Español (`es`), Inglés (`en`), y puede extenderse fácilmente.
* Estructura de ejemplo de `i18n.json`:

```json
{
  "es": {
    "glab_not_found": "glab.exe no encontrado. Descargando última versión...",
    "downloading": "Descargando glab.exe {0} desde {1} ..."
  },
  "en": {
    "glab_not_found": "glab.exe not found. Downloading latest version...",
    "downloading": "Downloading glab.exe {0} from {1} ..."
  }
}
```

---

## Notas

* Asegúrate de que el token de GitLab tenga permisos suficientes para acceder a los repositorios del grupo.
* El script desactiva la verificación SSL temporalmente por conveniencia; úsalo solo en redes confiables.
* La carpeta de configuración requerida se creará automáticamente cuando ejecutes el script por primera vez.
* Después de crear la carpeta, modifica el archivo de configuración para apuntar a tu host GitLab y establece `git_protocol: https`.
* Para obtener más información sobre la configuración de `glab`, consulta la [documentación oficial](https://docs.gitlab.com/ee/integration/glab/).
