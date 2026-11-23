# ============================================
# Auto-Sync Markdown to HTML
# ============================================
# Watches md/ folder for changes and auto-converts to html/ folder
#
# Usage:
#   .\sync-md-to-html.ps1              # Convert all changed files
#   .\sync-md-to-html.ps1 -Watch       # Watch for changes (runs continuously)
#   .\sync-md-to-html.ps1 -All         # Force convert all files

param(
    [switch]$Watch,     # Watch mode (continuous monitoring)
    [switch]$All        # Convert all files (not just changed)
)

$coursePath = "C:\Users\kasekar\GH\Course"
$mdPath = Join-Path $coursePath "md"
$htmlPath = Join-Path $coursePath "html"

Write-Host "🔄 MD → HTML Auto-Sync" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "📂 Source: $mdPath" -ForegroundColor Yellow
Write-Host "📂 Target: $htmlPath" -ForegroundColor Yellow
Write-Host ""

# Ensure folders exist
if (-not (Test-Path $mdPath)) {
    Write-Host "❌ Error: md/ folder not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $htmlPath)) {
    New-Item -ItemType Directory -Path $htmlPath -Force | Out-Null
    Write-Host "✅ Created html/ folder" -ForegroundColor Green
}

# HTML Template
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{TITLE}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.8;
            background: #f5f5f5;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        h1 {
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }
        h2 {
            color: #764ba2;
            margin-top: 30px;
            margin-bottom: 15px;
        }
        h3 {
            color: #333;
            margin-top: 20px;
            margin-bottom: 10px;
        }
        p {
            margin-bottom: 15px;
            color: #333;
        }
        ul, ol {
            margin-left: 30px;
            margin-bottom: 15px;
        }
        li {
            margin-bottom: 8px;
        }
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
            color: #c7254e;
        }
        pre {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            margin-bottom: 15px;
        }
        pre code {
            background: none;
            color: inherit;
            padding: 0;
        }
        blockquote {
            border-left: 4px solid #667eea;
            padding-left: 20px;
            margin: 20px 0;
            color: #666;
            font-style: italic;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background: #667eea;
            color: white;
        }
        tr:nth-child(even) {
            background: #f9f9f9;
        }
        a {
            color: #667eea;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .back-link {
            display: inline-block;
            margin-bottom: 20px;
            padding: 10px 20px;
            background: #667eea;
            color: white;
            border-radius: 5px;
            text-decoration: none;
        }
        .back-link:hover {
            background: #764ba2;
        }
        hr {
            border: none;
            border-top: 2px solid #ddd;
            margin: 30px 0;
        }
        .metadata {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            font-size: 0.9em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <a href="../navigation.html" class="back-link">← Back to Navigation</a>
        <div class="metadata">
            📄 <strong>Source:</strong> md/{FILENAME}.md |
            🕐 <strong>Last Updated:</strong> {TIMESTAMP}
        </div>
        {CONTENT}
    </div>
</body>
</html>
'@

# Simple Markdown to HTML converter
function Convert-MarkdownToHtml {
    param([string]$markdown)

    $html = $markdown -replace '&', '&amp;'
    $html = $html -replace '<', '&lt;'
    $html = $html -replace '>', '&gt;'

    # Headers
    $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'

    # Bold and Italic
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*(.+?)\*', '<em>$1</em>'

    # Inline code
    $html = $html -replace '`([^`]+)`', '<code>$1</code>'

    # Links
    $html = $html -replace '\[([^\]]+)\]\(([^\)]+)\)', '<a href="$2">$1</a>'

    # Horizontal rules
    $html = $html -replace '(?m)^---$', '<hr>'

    # Blockquotes
    $html = $html -replace '(?m)^&gt; (.+)$', '<blockquote>$1</blockquote>'

    # Lists
    $html = $html -replace '(?m)^- (.+)$', '<li>$1</li>'
    $html = $html -replace '(?m)^\* (.+)$', '<li>$1</li>'
    $html = $html -replace '(<li>.*?</li>(\r?\n<li>.*?</li>)+)', '<ul>$1</ul>'

    # Paragraphs
    $lines = $html -split "`n"
    $processedLines = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -ne '' -and $trimmed -notmatch '^<(h[1-6]|ul|ol|li|blockquote|hr|pre|table)') {
            $processedLines += "<p>$trimmed</p>"
        } else {
            $processedLines += $trimmed
        }
    }
    $html = $processedLines -join "`n"

    return $html
}

# Convert a single file
function Convert-File {
    param(
        [string]$mdFilePath,
        [switch]$Force
    )

    $mdFile = Get-Item $mdFilePath
    $htmlFileName = $mdFile.BaseName + ".html"
    $htmlFilePath = Join-Path $htmlPath $htmlFileName

    # Check if conversion needed
    if (-not $Force -and (Test-Path $htmlFilePath)) {
        $htmlFile = Get-Item $htmlFilePath
        if ($htmlFile.LastWriteTime -gt $mdFile.LastWriteTime) {
            Write-Host "⏭️  Skipped: $($mdFile.Name) (HTML is up-to-date)" -ForegroundColor Gray
            return $false
        }
    }

    try {
        # Read markdown
        $markdownContent = Get-Content -Path $mdFilePath -Raw -Encoding UTF8

        # Extract title
        $title = "Course Document"
        if ($markdownContent -match '(?m)^#\s+(.+)$') {
            $title = $Matches[1]
        }

        # Convert
        $htmlContent = Convert-MarkdownToHtml -markdown $markdownContent

        # Apply template
        $finalHtml = $htmlTemplate -replace '\{TITLE\}', $title
        $finalHtml = $finalHtml -replace '\{FILENAME\}', $mdFile.BaseName
        $finalHtml = $finalHtml -replace '\{TIMESTAMP\}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        $finalHtml = $finalHtml -replace '\{CONTENT\}', $htmlContent

        # Write HTML
        Set-Content -Path $htmlFilePath -Value $finalHtml -Encoding UTF8

        Write-Host "✅ Converted: $($mdFile.Name) → html\$htmlFileName" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "❌ Error converting $($mdFile.Name): $_" -ForegroundColor Red
        return $false
    }
}

# Main conversion logic
if ($Watch) {
    Write-Host "👀 Watch mode enabled - monitoring md/ folder for changes..." -ForegroundColor Cyan
    Write-Host "   Press Ctrl+C to stop" -ForegroundColor Gray
    Write-Host ""

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $mdPath
    $watcher.Filter = "*.md"
    $watcher.IncludeSubdirectories = $false
    $watcher.EnableRaisingEvents = $true

    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType
        Write-Host "📝 Detected change: $changeType - $(Split-Path $path -Leaf)" -ForegroundColor Yellow

        Start-Sleep -Milliseconds 500  # Debounce
        Convert-File -mdFilePath $path -Force
    }

    Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
    Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    } finally {
        $watcher.Dispose()
    }

} else {
    # One-time conversion
    $mdFiles = Get-ChildItem -Path $mdPath -Filter "*.md" -File
    $convertedCount = 0

    Write-Host "🔄 Converting files..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($mdFile in $mdFiles) {
        if (Convert-File -mdFilePath $mdFile.FullName -Force:$All) {
            $convertedCount++
        }
    }

    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "✅ Sync Complete!" -ForegroundColor Green
    Write-Host "   Converted: $convertedCount / $($mdFiles.Count) files" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Tip: Use -Watch to monitor for changes" -ForegroundColor Yellow
}

# Note
Write-Host ""
Write-Host "📋 Usage:" -ForegroundColor Cyan
Write-Host "   .\sync-md-to-html.ps1              # Convert changed files" -ForegroundColor Gray
Write-Host "   .\sync-md-to-html.ps1 -All         # Convert all files" -ForegroundColor Gray
Write-Host "   .\sync-md-to-html.ps1 -Watch       # Watch for changes" -ForegroundColor Gray