# GitLab Clone All Script

**Important prerequisites before using the script:**

* **Install your SSL certificate** to avoid SSL issues. Download it from your GitLab server via your browser and install it on your PC.

* **Run the script once to create the necessary folders**. `glab` will generate these automatically on the first run:

  ```
  D:\Users\your_user\.config\glab-cli
  ```

* **After the folders are created, modify the configuration** to point to your own GitLab host and set `git_protocol: https`.

---

## Overview

This PowerShell script allows you to **clone or update all repositories from a specific GitLab group** (including subgroups) automatically. It is internationalizable and supports multiple languages via a JSON translations file (`i18n.json`).

The script uses `glab.exe` (GitLab CLI) for cloning and falls back to `git clone` if necessary.

---

## Features

* Automatic detection of system language or selection via `-Lang` parameter.
* Downloads the latest `glab.exe` if not present locally.
* Handles authentication with your GitLab host via personal access token.
* Processes all repositories in a group, including subgroups.
* Performs `git pull --recurse-submodules` if the repository already exists.
* Fallback to `git clone` if `glab` fails.
* Debug mode to trace script execution.
* Automatically creates necessary configuration folders on first execution.

---

## Requirements

* PowerShell 5.1+ or PowerShell Core
* Git installed and available in PATH
* Internet access to download `glab.exe` (unless already present)
* Personal access token for your GitLab host

## ⚠️ Security Warnings

* **Never commit your GitLab token** to version control. Pass it as a parameter or via secure input.
* The token is stored in plaintext in memory during script execution - only use in secure environments.
* The script disables SSL verification (`GIT_SSL_NO_VERIFY=true`) for convenience; use only behind trusted firewalls.
* Do not expose your personal access token in scripts, logs, or environment variables.

---

## Installation

1. Clone or download this repository.

2. Place `gitlab_clone_all.ps1` and `i18n.json` in the same directory.

3. Ensure your PowerShell execution policy allows script execution:

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

4. Download and install SSL certificates from your GitLab server if necessary (to avoid SSL verification issues).

---

## Usage

Basic usage:

```powershell
.\gitlab_clone_all.ps1 -Hostname "gitlab.example.com" -Group "mygroup/subgroup" -Token "your_personal_token"
```

Force a language (e.g., English):

```powershell
.\gitlab_clone_all.ps1 -Lang en
```

Enable debug logs:

```powershell
.\gitlab_clone_all.ps1 -Debug
```

### Parameters

| Parameter   | Description                                                  |
| ----------- | ------------------------------------------------------------ |
| `-Lang`     | Force the language for messages (default is system language) |
| `-Hostname` | GitLab host (default: your-gitlab-server.com)               |
| `-Group`    | GitLab group path (default: your-group/your-project)        |
| `-Token`    | Personal access token for authentication                     |
| `-Debug`    | Enable debug logging                                         |

---

## How it works

1. Loads translations from `i18n.json`.

2. Detects language (or uses forced language).

3. Checks if `glab.exe` exists; if not, downloads the latest release.

4. Authenticates with your GitLab host using the provided token.

5. Retrieves all projects from the group (including subgroups) using GitLab API.

6. For each repository:

   * If already cloned, runs `git pull --recurse-submodules`.
   * If not cloned, tries `glab repo clone`.
   * If `glab` fails, falls back to `git clone`.

7. Prints completion message with repository base path.

---

## Example Output

```text
Selected language: en
Using default values:
Hostname: gitlab.example.com
Group/Project: mygroup/subgroup
Token: (hidden)
Authenticating on gitlab.example.com ...
Repository 'mygroup/repo1' already exists. Pulling latest changes...
Cloning repository 'mygroup/repo2' ...
Cloning repository with glab: https://gitlab.example.com/mygroup/repo2.git
Process completed. Repositories are located in C:\Users\user\repos
```

---

## Translation

* The script supports multiple languages through `i18n.json`.
* Default supported languages: Spanish (`es`), English (`en`), and can be extended.
* Example `i18n.json` structure:

```json
{
  "en": {
    "glab_not_found": "glab.exe not found. Downloading latest version...",
    "downloading": "Downloading glab.exe {0} from {1} ..."
  },
  "es": {
    "glab_not_found": "No se encontró glab.exe. Descargando la última versión...",
    "downloading": "Descargando glab.exe {0} desde {1} ..."
  }
}
```

---

## Notes

* Make sure the GitLab token has sufficient permissions for the group repositories.
* The script disables SSL verification temporarily for convenience; use only in trusted networks.
* The required configuration folder will be automatically created when the script is executed for the first time.
* After the folder is created, modify the configuration file to point to your GitLab host and set `git_protocol: https`.

---

## License

This repository is provided under the MIT License.
