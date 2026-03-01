$ErrorActionPreference = "Stop"

# Initialize VS2026 dev shell
$vsPath = "C:\Program Files\Microsoft Visual Studio\18\Community"
$devShell = Join-Path $vsPath "Common7\Tools\Launch-VsDevShell.ps1"
if (Test-Path $devShell) {
    & $devShell -Arch amd64 -SkipAutomaticLocation
    Write-Host "VS2026 dev shell initialized"
} else {
    # Try VS2022 fallback
    $vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
    $devShell = Join-Path $vsPath "Common7\Tools\Launch-VsDevShell.ps1"
    if (Test-Path $devShell) {
        & $devShell -Arch amd64 -SkipAutomaticLocation
        Write-Host "VS2022 dev shell initialized"
    } else {
        Write-Error "No Visual Studio dev shell found"
        exit 1
    }
}

# Force vcpkg settings
$env:VCPKG_ROOT = "C:\vcpkg"
$env:VCPKG_VISUAL_STUDIO_PATH = $vsPath

$srcDir = $PSScriptRoot
$buildDir = Join-Path $srcDir "build"

Write-Host "Configuring CMake..."
cmake -B $buildDir -S $srcDir -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" `
    -DVCPKG_TARGET_TRIPLET=x64-windows-static

if ($LASTEXITCODE -ne 0) {
    Write-Error "CMake configure failed"
    exit 1
}

Write-Host "Building..."
cmake --build $buildDir --config Release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
    exit 1
}

# Copy DLL to Native root for easy access
$dllPath = Get-ChildItem -Path $buildDir -Filter "SeverActionsNative.dll" -Recurse | Select-Object -First 1
if ($dllPath) {
    Copy-Item $dllPath.FullName -Destination (Join-Path $srcDir "SeverActionsNative.dll") -Force
    Write-Host "DLL copied to: $(Join-Path $srcDir 'SeverActionsNative.dll')"
    Write-Host "Size: $([math]::Round($dllPath.Length / 1KB, 1)) KB"
} else {
    Write-Error "DLL not found in build output"
    exit 1
}

Write-Host "Build completed successfully!"
