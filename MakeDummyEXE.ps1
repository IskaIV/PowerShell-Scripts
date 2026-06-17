$cs = "$env:TEMP\DoNothing.cs"
$out = "$env:USERPROFILE\Desktop\DoNothing.exe"

@'
using System;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        return 0;
    }
}
'@ | Set-Content -Path $cs -Encoding ASCII

$csc = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $csc) {
    throw "csc.exe not found. Install .NET Framework Developer Pack or Visual Studio Build Tools."
}

& $csc /nologo /target:winexe /optimize+ /out:$out $cs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Created: $out"
}