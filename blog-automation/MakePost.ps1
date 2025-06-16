#Requires -PSEdition Core
$templatePath = "$PSScriptRoot\template.html"
$markdownPath = Get-Item $args[0] -ErrorAction Stop |
    Select-Object -ExpandProperty FullName
$htmlPath = [IO.Path]::ChangeExtension($markdownPath, '.html')
$sourceWithScriptPath = "Temp:\$(
    New-Guid |
    Select-Object -ExpandProperty Guid
).html"
$sourceNoScriptPath = "Temp:\$(
    New-Guid |
    Select-Object -ExpandProperty Guid
).html"

"{0}{2}{1}" -f @(
    ((Get-Content $templatePath -Raw) -split '\n<!-- __CONTENT__ -->\n') +
    (
        Get-Content $markdownPath -Raw |
        ConvertFrom-Markdown |
        Select-Object -ExpandProperty Html
    )
) | Out-File $sourceWithScriptPath -Encoding utf8 -NoNewline

Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList @(
    '--headless'
    '--disable-gpu'
    '--dump-dom'
    '--single-argument'
    (Get-Item $sourceWithScriptPath).FullName
) -RedirectStandardOutput $sourceNoScriptPath -Wait -NoNewWindow

(Get-Content $sourceNoScriptPath) -notmatch '^<!-- __HIGHLIGHTJS__ -->' |
Out-String |
Out-File $htmlPath -Encoding utf8 -NoNewline