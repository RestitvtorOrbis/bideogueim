$ErrorActionPreference = "Stop"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Desktop is unavailable. Install and start Docker Desktop before running the benchmark."
}

New-Item -ItemType Directory -Force -Path "reports" | Out-Null
docker compose run --rm --build benchmark
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}
