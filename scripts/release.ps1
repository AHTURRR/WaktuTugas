[CmdletBinding()]
param(
    [string]$Device = $env:WAKTUTUGAS_ANDROID_DEVICE,
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$PublishableKey = $env:SUPABASE_PUBLISHABLE_KEY,
    [switch]$ApplyMigrations
)

$ErrorActionPreference = 'Stop'
$env:SUPABASE_TELEMETRY_DISABLED = '1'
Set-Location (Join-Path $PSScriptRoot '..')
$wib = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7))
$runDir = New-Item -ItemType Directory -Path "build/release/$($wib.ToString('yyyyMMdd-HHmmss-fff'))"
$report = Join-Path $runDir.FullName 'hasil.md'
@(
    '# Pemeriksaan rilis WaktuTugas'
    ''
    "Waktu $($wib.ToString('yyyy-MM-dd HH:mm:ss')) WIB"
    "Commit dasar $(git rev-parse --short HEAD)"
    ''
    '| Pemeriksaan | Hasil | Tindak lanjut |'
    '| --- | --- | --- |'
) | Set-Content -LiteralPath $report -Encoding UTF8

function Write-Result($Name, $Status, $FollowUp = '') {
    Write-Host "[$Status] $Name $FollowUp"
    Add-Content -LiteralPath $report -Encoding UTF8 -Value "| $Name | $Status | $FollowUp |"
}

function Invoke-Check($Name, $FollowUp, [scriptblock]$Run) {
    Write-Host "Menjalankan $Name"
    try {
        $global:LASTEXITCODE = 0
        & $Run | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Exit code $LASTEXITCODE" }
        Write-Result $Name 'Lulus'
        return $true
    } catch {
        Write-Result $Name 'Gagal' $FollowUp
        return $false
    }
}

$cloud = $SupabaseUrl -match '^https://[a-z0-9]{20}\.supabase\.co/?$' -and
    $PublishableKey -cmatch '^sb_publishable_[A-Za-z0-9_-]+$'
$projectRef = if ($cloud) { ([uri]$SupabaseUrl).Host.Split('.')[0] }
$validTarget = $cloud -or (-not $SupabaseUrl -and -not $PublishableKey -and -not $ApplyMigrations)

$deps = Invoke-Check 'Dependensi Flutter' 'Periksa Flutter SDK dan akses paket.' { flutter pub get }
$format = Invoke-Check 'Format Dart' 'Format file yang dilaporkan Dart.' {
    dart format --output=none --set-exit-if-changed lib test integration_test
}
$analyze = Invoke-Check 'Analisis Flutter' 'Perbaiki temuan flutter analyze.' { flutter analyze --no-pub }
$tests = Invoke-Check 'Tes planner, UI, dan data' 'Jalankan ulang tes yang gagal setelah memperbaiki penyebabnya.' {
    flutter test --no-pub test/planner test/ui test/data
}

$sql = $false
$rpc = $false
$stack = $false
$supabase = if (Get-Command supabase.cmd -ErrorAction SilentlyContinue) { 'supabase.cmd' } else { 'supabase' }
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $stack = Invoke-Check 'Supabase lokal' 'Periksa keluaran supabase start.' { & $supabase start | Out-Null }
        if ($stack) {
            $sql = Invoke-Check 'Tes SQL' 'Periksa keluaran pgTAP dan migrasi.' { & $supabase test db }
            $rpc = Invoke-Check 'Tes RPC dua akun' 'Periksa Auth lokal, snapshot, dan keluaran tes RPC.' {
                $statusJson = & $supabase status -o json
                if ($LASTEXITCODE -ne 0) { throw 'Supabase status gagal' }
                $status = $statusJson | ConvertFrom-Json
                $localKey = $status.PUBLISHABLE_KEY
                if (-not $localKey) { $localKey = $status.ANON_KEY }
                if (-not $localKey) { throw 'Publishable key lokal tidak tersedia' }
                $localUrl = 'http://127.0.0.1:54321'
                $accounts = @{}
                foreach ($account in 'A', 'B') {
                    $id = [guid]::NewGuid().ToString('N')
                    $email = "release-$id@example.com"
                    $password = "Wt-$id!"
                    Invoke-RestMethod -Method Post -Uri "$localUrl/auth/v1/signup" -Headers @{ apikey = $localKey } `
                        -ContentType 'application/json' -Body (@{email = $email; password = $password} | ConvertTo-Json) | Out-Null
                    $accounts["WAKTUTUGAS_TEST_${account}_EMAIL"] = $email
                    $accounts["WAKTUTUGAS_TEST_${account}_PASSWORD"] = $password
                }
                $accounts['SUPABASE_URL'] = $localUrl
                $accounts['SUPABASE_PUBLISHABLE_KEY'] = $localKey
                $previous = @{}
                try {
                    foreach ($name in $accounts.Keys) {
                        $previous[$name] = [Environment]::GetEnvironmentVariable($name)
                        [Environment]::SetEnvironmentVariable($name, $accounts[$name])
                    }
                    flutter test --no-pub test/backend/planner_rpc_test.dart
                } finally {
                    foreach ($name in $previous.Keys) {
                        [Environment]::SetEnvironmentVariable($name, $previous[$name])
                    }
                }
            }
        }
    }
}
if (-not $stack) {
    Write-Result 'Tes SQL dan RPC' 'Tertunda' 'Pastikan Docker dan Supabase lokal berjalan.'
}

$android = $false
if ($Device) {
    $android = Invoke-Check 'Integrasi Android' 'Periksa ID perangkat dan hasil integration_test.' {
        flutter test --no-pub --no-uninstall integration_test -d $Device
    }
} else {
    Write-Result 'Integrasi Android' 'Tertunda' 'Isi -Device dengan ID dari flutter devices.'
}

$apk = Join-Path $runDir.FullName 'WaktuTugas-demo.apk'
$buildArgs = @('build', 'apk', '--release')
if ($cloud) {
    $apk = Join-Path $runDir.FullName 'WaktuTugas-candidate.apk'
    $buildArgs += "--dart-define=SUPABASE_URL=$SupabaseUrl", "--dart-define=SUPABASE_PUBLISHABLE_KEY=$PublishableKey"
} else {
    Write-Result 'Supabase tujuan' 'Tertunda' 'Isi -SupabaseUrl HTTPS proyek dan -PublishableKey.'
}

$built = $false
if ($validTarget -and $deps) {
    $built = Invoke-Check 'Build APK bertanda tangan' 'Periksa build Flutter dan konfigurasi android/key.properties.' {
        flutter @buildArgs
        if ($LASTEXITCODE -eq 0) {
            Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $apk
        }
    }
} else {
    Write-Result 'Build APK' 'Tertunda' 'Perbaiki dependensi atau konfigurasi Supabase sebelum build.'
}

$verified = $false
if ($built) {
    $verified = Invoke-Check 'Verifikasi tanda tangan APK' 'Periksa Android SDK Build Tools dan Java untuk apksigner.' {
        $sdk = (Get-Content android/local.properties | Select-String '^sdk.dir=').Line -replace '^sdk.dir=', '' -replace '\\\\', '\'
        $apkSigner = Get-ChildItem -Path "$sdk/build-tools/*/apksigner.bat" |
            Sort-Object FullName -Descending | Select-Object -First 1
        & $apkSigner.FullName verify --print-certs $apk
    }
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
    Write-Result 'Artefak APK' 'Tersedia' ('`{0}` {1}' -f (Split-Path -Leaf $apk), $hash)
}

$checksPassed = $deps -and $format -and $analyze -and $tests -and $sql -and $rpc -and $android -and $verified
if ($cloud) {
    $preview = Invoke-Check 'Pratinjau migrasi tujuan' 'Periksa login Supabase CLI dan akses ke proyek tujuan.' {
        & $supabase db push "--remote=$projectRef" --dry-run
    }
    if ($ApplyMigrations -and $preview -and $checksPassed) {
        $migrated = Invoke-Check 'Migrasi Supabase tujuan' 'Periksa keluaran migrasi sebelum mengulang.' {
            & $supabase db push "--remote=$projectRef" --yes
        }
    } else {
        Write-Result 'Migrasi Supabase tujuan' 'Tertunda' 'Gunakan -ApplyMigrations setelah pratinjau dan pemeriksaan lulus, atau konfirmasi skema sudah diterapkan.'
    }
}

if ($Device -and $verified) {
    $installed = Invoke-Check 'Instalasi APK kandidat' 'Periksa koneksi perangkat dan kecocokan tanda tangan aplikasi yang terpasang.' {
        $sdk = (Get-Content android/local.properties | Select-String '^sdk.dir=').Line -replace '^sdk.dir=', '' -replace '\\\\', '\'
        & "$sdk/platform-tools/adb.exe" -s $Device install -r $apk
    }
}
Write-Result 'Uji alur APK final dan distribusi' 'Tertunda' 'Catat uji akun di APK final dan tinjau hasil sebelum membuat tag atau membagikan APK.'
Write-Host "Laporan $report"
if (-not ($checksPassed -and $cloud -and $preview -and $installed) -or ($ApplyMigrations -and -not $migrated)) {
    exit 1
}
