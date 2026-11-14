# WorldQuest - Prepara la carpeta para subir el mod al Workshop de Steam
# Uso (desde la carpeta del repo):  .\tools\preparar-workshop.ps1
# Despues: Project Zomboid > Workshop > Crear y actualizar > WorldQuest.

param(
    [string]$Destino = "$env:USERPROFILE\Zomboid\Workshop\WorldQuest"
)

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot
$Contenido = Join-Path $Destino "Contents"
$Mods = Join-Path $Contenido "mods\WorldQuest"

# Contents se rehace siempre; workshop.txt se conserva si ya existe, porque despues
# de la primera subida el juego le agrega la linea id= que identifica el item
if (Test-Path $Contenido) {
    Remove-Item $Contenido -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Mods | Out-Null
Copy-Item -Recurse -Force (Join-Path $Repo "WorldQuest\*") $Mods
Copy-Item -Force (Join-Path $Repo "workshop\preview.png") $Destino

$Txt = Join-Path $Destino "workshop.txt"
if (-not (Test-Path $Txt)) {
    Copy-Item -Force (Join-Path $Repo "workshop\workshop.txt") $Txt
    Write-Host "workshop.txt nuevo copiado."
} else {
    Write-Host "workshop.txt existente conservado (mantiene el id del item)."
}

$Version = (Select-String -Path (Join-Path $Repo "WorldQuest\42\mod.info") -Pattern "^modversion=").Line
Write-Host "Listo: $Destino ($Version)"
Write-Host "Ojo: si tambien tienes el junction en Zomboid\mods\WorldQuest, el juego puede mostrar el mod dos veces."
