Set-StrictMode -Version Latest

foreach ($folder in @('Private', 'Public')) {
    $path = Join-Path $PSScriptRoot $folder
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter '*.ps1' | ForEach-Object { . $_.FullName }
    }
}

Update-TypeData -TypeName 'LichiiGamepad.HostCheck' -DefaultDisplayPropertySet 'Status', 'Area', 'Message' -Force
