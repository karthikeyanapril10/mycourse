# Fixed MD to HTML Sync Script - Proper UTF-8 handling
# Uses .NET methods to avoid PowerShell encoding issues

$mdPath = "C:\Users\kasekar\GH\Course\md"
$htmlPath = "C:\Users\kasekar\GH\Course\html"

Write-Host "Syncing MD to HTML (UTF-8 Fixed)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Ensure html folder exists
if (-not (Test-Path $htmlPath)) {
    New-Item -ItemType Directory -Path $htmlPath | Out-Null
}

# Get all MD files
$mdFiles = Get-ChildItem -Path $mdPath -Filter "*.md" -File
Write-Host "Found: $($mdFiles.Count) markdown files" -ForegroundColor Yellow
Write-Host ""

$converted = 0
$utf8NoBOM = New-Object System.Text.UTF8Encoding $false

foreach ($mdFile in $mdFiles) {
    $htmlFile = Join-Path $htmlPath ($mdFile.BaseName + ".html")

    Write-Host "Converting: $($mdFile.Name)" -ForegroundColor Green

    # Read markdown using .NET (preserves UTF-8)
    $content = [System.IO.File]::ReadAllText($mdFile.FullName, $utf8NoBOM)

    # Simple markdown conversion
    $html = $content
    $html = $html -replace '&', '&amp;'
    $html = $html -replace '<', '&lt;'
    $html = $html -replace '>', '&gt;'
    $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*(.+?)\*', '<em>$1</em>'
    $html = $html -replace '`([^`]+)`', '<code>$1</code>'
    $html = $html -replace '\[([^\]]+)\]\(([^\)]+)\)', '<a href="$2">$1</a>'
    $html = $html -replace '(?m)^---$', '<hr>'
    $html = $html -replace '(?m)^- (.+)$', '<li>$1</li>'

    # Wrap in HTML template
    $finalHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$($mdFile.BaseName)</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; padding: 40px; max-width: 1000px; margin: 0 auto; background: #f5f5f5; }
        .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #667eea; border-bottom: 3px solid #667eea; padding-bottom: 10px; }
        h2 { color: #764ba2; margin-top: 30px; }
        h3 { color: #333; margin-top: 20px; }
        code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; color: #c7254e; }
        a { color: #667eea; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .back { display: inline-block; margin-bottom: 20px; padding: 10px 20px; background: #667eea; color: white; border-radius: 5px; }
        li { margin-bottom: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <a href="../navigation.html" class="back">&larr; Back</a>
        <div style="background: #f8f9fa; padding: 10px; border-radius: 5px; margin-bottom: 20px; font-size: 0.9em;">
            Source: md/$($mdFile.Name) | Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        </div>
        $html
    </div>
</body>
</html>
"@

    # Write using .NET (preserves UTF-8 emojis)
    [System.IO.File]::WriteAllText($htmlFile, $finalHtml, $utf8NoBOM)
    $converted++
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Complete! Converted: $converted files" -ForegroundColor Green
Write-Host "Output: $htmlPath" -ForegroundColor Yellow
