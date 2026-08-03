$ErrorActionPreference = "Stop"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Desktop is unavailable. Install and start Docker Desktop before exporting."
}

$preset = Test-Path "export_presets.cfg" -PathType Leaf
if (-not $preset) {
    throw "The Windows Desktop export preset is missing from export_presets.cfg."
}

New-Item -ItemType Directory -Force -Path "exports/windows" | Out-Null
docker compose run --rm --build export-windows
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}

if (-not (Test-Path "exports/windows/UrbanDrivePrototype.exe")) {
    throw "Godot did not produce exports/windows/UrbanDrivePrototype.exe."
}

if (-not (Test-Path "exports/windows/UrbanDrivePrototype.pck")) {
    throw "Godot did not produce exports/windows/UrbanDrivePrototype.pck."
}
