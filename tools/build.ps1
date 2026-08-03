$ErrorActionPreference = "Stop"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Desktop is unavailable. Install and start Docker Desktop before building the Godot tools image."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is installed but not running. Start Docker Desktop and retry."
}

docker compose build godot-tools
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
