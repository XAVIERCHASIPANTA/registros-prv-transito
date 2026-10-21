# Deja de rastrear en Git los archivos que no deben estar en el repositorio.
# NO borra nada de tu PC: solo los saca del control de versiones.
# Uso: abrir PowerShell en la carpeta del proyecto y ejecutar:  .\limpiar_repo_git.ps1
# Luego, en GitHub Desktop: Commit y Push.

$ErrorActionPreference = 'Stop'
git rm -r --cached --ignore-unmatch push_err.txt push_out.txt scratch .firebase
git status --short
Write-Host ""
Write-Host "Listo. Ahora haz Commit y Push desde GitHub Desktop." -ForegroundColor Green
