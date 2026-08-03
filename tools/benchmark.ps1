param(
    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 600
)

$ErrorActionPreference = "Stop"

$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $docker) {
    throw "Docker Desktop is unavailable. Install and start Docker Desktop before running the benchmark."
}

New-Item -ItemType Directory -Force -Path "reports" | Out-Null
$benchmarkCommand = @(
    "--headless",
    "--path",
    "/workspace",
    "--scene",
    "res://scenes/CrowdBenchmark.tscn",
    "--",
    "--benchmark-seconds",
    $DurationSeconds.ToString(),
    "--report",
    "res://reports/benchmark.json"
)
docker compose run --rm --build benchmark @benchmarkCommand
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    exit $exitCode
}
