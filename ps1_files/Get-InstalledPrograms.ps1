function Get-InstalledPrograms {

    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $DisplayName
    );

    Set-StrictMode -Off;
    if ( -not $DisplayName ) {
        $DisplayName = '*';
    }
    Get-ItemProperty -Path $(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*';
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*';
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';
        'HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*';
    ) -ErrorAction 'SilentlyContinue' |
    Where-Object -Property 'DisplayName' -Like $DisplayName |
    Select-Object -Property 'DisplayName', 'UninstallString', 'ModifyPath' |
    Sort-Object -Property 'DisplayName';
}