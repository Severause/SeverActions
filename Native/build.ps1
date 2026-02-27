# build.ps1 - Build script for SeverActionsNative SKSE plugin
# Uses CommonLibSSE-NG with vcpkg integration

param(
    [switch]$Clean,
    [switch]$Verbose,
    [switch]$SetupVcpkg  # Install standalone vcpkg if not present
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SeverActionsNative Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find Visual Studio installation
Write-Host "Finding Visual Studio installation..." -ForegroundColor Yellow

# Try to find vswhere.exe
$vswhereLocations = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
)

$vswhere = $null
foreach ($loc in $vswhereLocations) {
    if (Test-Path $loc) {
        $vswhere = $loc
        break
    }
}

if ($vswhere) {
    Write-Host "Using vswhere: $vswhere"
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
} else {
    Write-Host "vswhere.exe not found, searching manually..." -ForegroundColor Yellow
    $possiblePaths = @(
        "C:\Program Files\Microsoft Visual Studio\2024\Community",
        "C:\Program Files\Microsoft Visual Studio\2024\Professional",
        "C:\Program Files\Microsoft Visual Studio\2024\Enterprise",
        "C:\Program Files\Microsoft Visual Studio\2022\Community",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional",
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise",
        "C:\Program Files\Microsoft Visual Studio\18\Community",
        "C:\Program Files\Microsoft Visual Studio\17\Community"
    )

    $vsPath = $null
    foreach ($path in $possiblePaths) {
        $vcvarsTest = Join-Path $path "VC\Auxiliary\Build\vcvars64.bat"
        if (Test-Path $vcvarsTest) {
            $vsPath = $path
            Write-Host "Found VS at: $vsPath"
            break
        }
    }
}

if (-not $vsPath) {
    Write-Host "ERROR: Visual Studio with C++ workload not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Visual Studio path: $vsPath" -ForegroundColor Green

# Setup Visual Studio environment
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
if (Test-Path $vcvars) {
    Write-Host "Loading VS environment from: $vcvars"
    cmd /c "`"$vcvars`" && set" | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
    Write-Host "Visual Studio environment loaded." -ForegroundColor Green
} else {
    Write-Host "ERROR: vcvars64.bat not found!" -ForegroundColor Red
    exit 1
}

# Standalone vcpkg location
$vcpkgStandalone = "C:\vcpkg"

# Setup standalone vcpkg if requested or if we don't have a working one
if ($SetupVcpkg -or (-not $env:VCPKG_ROOT)) {
    if (-not (Test-Path "$vcpkgStandalone\vcpkg.exe")) {
        Write-Host ""
        Write-Host "Setting up standalone vcpkg at $vcpkgStandalone..." -ForegroundColor Yellow
        Write-Host "(This is needed because VS 2024's embedded vcpkg has issues detecting VS)"
        Write-Host ""

        if (-not (Test-Path $vcpkgStandalone)) {
            Write-Host "Cloning vcpkg repository..."
            git clone https://github.com/microsoft/vcpkg.git $vcpkgStandalone
            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Failed to clone vcpkg" -ForegroundColor Red
                exit 1
            }
        }

        Write-Host "Bootstrapping vcpkg..."
        & "$vcpkgStandalone\bootstrap-vcpkg.bat" -disableMetrics
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to bootstrap vcpkg" -ForegroundColor Red
            exit 1
        }

        Write-Host "vcpkg setup complete!" -ForegroundColor Green
    }

    $env:VCPKG_ROOT = $vcpkgStandalone
    Write-Host "Using standalone vcpkg: $env:VCPKG_ROOT" -ForegroundColor Green
}

# Check for required tools
Write-Host ""
Write-Host "Checking required tools..." -ForegroundColor Yellow

$cmakeVersion = cmake --version 2>$null | Select-Object -First 1
if ($cmakeVersion) {
    Write-Host "  CMake: $cmakeVersion" -ForegroundColor Green
} else {
    Write-Host "  CMake: NOT FOUND - Install with: winget install Kitware.CMake" -ForegroundColor Red
    exit 1
}

$ninjaVersion = ninja --version 2>$null
if ($ninjaVersion) {
    Write-Host "  Ninja: $ninjaVersion" -ForegroundColor Green
} else {
    Write-Host "  Ninja: NOT FOUND - Install with: winget install Ninja-build.Ninja" -ForegroundColor Red
    exit 1
}

$clPath = Get-Command cl.exe -ErrorAction SilentlyContinue
if ($clPath) {
    Write-Host "  MSVC: $($clPath.Source)" -ForegroundColor Green
} else {
    Write-Host "  MSVC: NOT FOUND" -ForegroundColor Red
    exit 1
}

# Use short build path
$buildDir = "C:\b\san"

Write-Host ""
Write-Host "Build directory: $buildDir" -ForegroundColor Yellow

# Clean if requested
if ($Clean -and (Test-Path $buildDir)) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir -ErrorAction SilentlyContinue
}

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

# Configure
Write-Host ""
Write-Host "Running CMake configure..." -ForegroundColor Yellow

$vcpkgToolchain = Join-Path $env:VCPKG_ROOT "scripts\buildsystems\vcpkg.cmake"

$cmakeArgs = @(
    "-G", "Ninja",
    "-B", $buildDir,
    "-S", $PSScriptRoot,
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_TOOLCHAIN_FILE=$vcpkgToolchain",
    "-DVCPKG_TARGET_TRIPLET=x64-windows-static",
    "-DCMAKE_C_COMPILER=cl.exe",
    "-DCMAKE_CXX_COMPILER=cl.exe"
)

Write-Host "VCPKG_ROOT: $env:VCPKG_ROOT"
Write-Host ""

& cmake $cmakeArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "CMake configure FAILED!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running with -SetupVcpkg to install standalone vcpkg:" -ForegroundColor Yellow
    Write-Host "  .\build.ps1 -SetupVcpkg -Clean" -ForegroundColor Cyan
    exit 1
}

# Build
Write-Host ""
Write-Host "Running build..." -ForegroundColor Yellow

& cmake --build $buildDir --config Release

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Build FAILED!" -ForegroundColor Red
    exit 1
}

# Copy DLL
$dll = Get-ChildItem "$buildDir\*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($dll) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "DLL: $($dll.FullName)" -ForegroundColor Cyan

    Copy-Item $dll.FullName -Destination $PSScriptRoot -Force
    Write-Host "Copied to: $PSScriptRoot\$($dll.Name)" -ForegroundColor Cyan

    $size = [math]::Round($dll.Length / 1KB, 1)
    Write-Host "Size: $size KB" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Installation:" -ForegroundColor Yellow
    Write-Host "  1. Copy $($dll.Name) to Data\SKSE\Plugins\"
    Write-Host "  2. Compile Scripts\Source\SeverActionsNative.psc"
    Write-Host "  3. Copy SeverActionsNative.pex to Data\Scripts\"
} else {
    Write-Host ""
    Write-Host "No DLL found!" -ForegroundColor Red
    exit 1
}
