$ErrorActionPreference = "Stop"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Desktop is unavailable. Install and start Docker Desktop before running tests."
}

docker compose run --rm --build test
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}
