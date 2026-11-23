# ============================================
# Convert Markdown to HTML
# ============================================
# Usage: .\convert-md-to-html.ps1
# Converts all .md files in current directory to .html
# Preserves original .md files (doesn't delete them)

param(
    [switch]$Preview,  # Preview what will be converted without actually converting
    [switch]$Overwrite # Overwrite existing .html files
)

Write-Host "🔄 Markdown to HTML Converter" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$coursePath = "C:\Users\kasekar\GH\Course"
$mdFiles = Get-ChildItem -Path $coursePath -Filter "*.md" -File

Write-Host "📂 Scanning: $coursePath" -ForegroundColor Yellow
Write-Host "📄 Found: $($mdFiles.Count) markdown files" -ForegroundColor Yellow
Write-Host ""

if ($mdFiles.Count -eq 0) {
    Write-Host "❌ No markdown files found!" -ForegroundColor Red
    exit
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
    </style>
</head>
<body>
    <div class="container">
        <a href="navigation.html" class="back-link">← Back to Navigation</a>
        {CONTENT}
    </div>
</body>
</html>
'@

# Simple Markdown to HTML converter (basic conversion)
function Convert-MarkdownToHtml {
    param([string]$markdown)

    # Escape HTML special characters first
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
    $html = $html -replace '__(.+?)__', '<strong>$1</strong>'
    $html = $html -replace '_(.+?)_', '<em>$1</em>'

    # Inline code
    $html = $html -replace '`([^`]+)`', '<code>$1</code>'

    # Links
    $html = $html -replace '\[([^\]]+)\]\(([^\)]+)\)', '<a href="$2">$1</a>'

    # Horizontal rules
    $html = $html -replace '(?m)^---$', '<hr>'
    $html = $html -replace '(?m)^\*\*\*$', '<hr>'

    # Blockquotes
    $html = $html -replace '(?m)^&gt; (.+)$', '<blockquote>$1</blockquote>'

    # Lists (simple conversion)
    $html = $html -replace '(?m)^- (.+)$', '<li>$1</li>'
    $html = $html -replace '(?m)^\* (.+)$', '<li>$1</li>'
    $html = $html -replace '(?m)^\d+\. (.+)$', '<li>$1</li>'

    # Wrap consecutive <li> tags in <ul>
    $html = $html -replace '(<li>.*?</li>(\r?\n<li>.*?</li>)+)', '<ul>$1</ul>'

    # Paragraphs (wrap non-tag lines)
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

$convertedCount = 0
$skippedCount = 0

foreach ($mdFile in $mdFiles) {
    $htmlFileName = $mdFile.BaseName + ".html"
    $htmlFilePath = Join-Path -Path $coursePath -ChildPath $htmlFileName

    # Skip if HTML already exists (unless -Overwrite specified)
    if ((Test-Path $htmlFilePath) -and -not $Overwrite) {
        Write-Host "⏭️  Skipped: $($mdFile.Name) (HTML exists, use -Overwrite to replace)" -ForegroundColor Gray
        $skippedCount++
        continue
    }

    if ($Preview) {
        Write-Host "📄 Would convert: $($mdFile.Name) → $htmlFileName" -ForegroundColor Cyan
        continue
    }

    try {
        # Read markdown content
        $markdownContent = Get-Content -Path $mdFile.FullName -Raw -Encoding UTF8

        # Extract title (first # heading)
        $title = "Course Document"
        if ($markdownContent -match '(?m)^#\s+(.+)$') {
            $title = $Matches[1]
        }

        # Convert markdown to HTML
        $htmlContent = Convert-MarkdownToHtml -markdown $markdownContent

        # Apply template
        $finalHtml = $htmlTemplate -replace '\{TITLE\}', $title
        $finalHtml = $finalHtml -replace '\{CONTENT\}', $htmlContent

        # Write HTML file
        Set-Content -Path $htmlFilePath -Value $finalHtml -Encoding UTF8

        Write-Host "✅ Converted: $($mdFile.Name) → $htmlFileName" -ForegroundColor Green
        $convertedCount++

    } catch {
        Write-Host "❌ Error converting $($mdFile.Name): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
if ($Preview) {
    Write-Host "📋 Preview Complete!" -ForegroundColor Yellow
    Write-Host "   Would convert: $($mdFiles.Count) files" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Run without -Preview to actually convert" -ForegroundColor Yellow
} else {
    Write-Host "✅ Conversion Complete!" -ForegroundColor Green
    Write-Host "   Converted: $convertedCount files" -ForegroundColor Green
    Write-Host "   Skipped: $skippedCount files" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📂 Output: $coursePath" -ForegroundColor Cyan
}

# Note about better conversion
Write-Host ""
Write-Host "💡 Note: This uses basic markdown conversion." -ForegroundColor Yellow
Write-Host "   For better results, install pandoc:" -ForegroundColor Yellow
Write-Host "   winget install pandoc" -ForegroundColor Gray
Write-Host "   Then use: pandoc input.md -o output.html" -ForegroundColor Gray