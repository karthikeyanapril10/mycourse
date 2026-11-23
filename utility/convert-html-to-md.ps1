# ============================================
# Convert HTML to Markdown
# ============================================
# Usage: .\convert-html-to-md.ps1
# Converts all .html files (except index.html, navigation.html, resume HTMLs) to .md
# Useful for editing HTML content back to markdown format

param(
    [switch]$Preview,  # Preview what will be converted without actually converting
    [switch]$Overwrite # Overwrite existing .md files
)

Write-Host "🔄 HTML to Markdown Converter" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

$coursePath = "C:\Users\kasekar\GH\Course"

# Exclude these HTML files (they're not content files)
$excludeFiles = @(
    'index.html',
    'navigation.html',
    'Karthikeyan_Sekar_Resume_Beautiful.html',
    'Karthikeyan_Sekar_Resume_ATS_Optimized.html'
)

$htmlFiles = Get-ChildItem -Path $coursePath -Filter "*.html" -File | Where-Object {
    $excludeFiles -notcontains $_.Name
}

Write-Host "📂 Scanning: $coursePath" -ForegroundColor Yellow
Write-Host "📄 Found: $($htmlFiles.Count) HTML files (excluding navigation/resume files)" -ForegroundColor Yellow
Write-Host ""

if ($htmlFiles.Count -eq 0) {
    Write-Host "ℹ️  No convertible HTML files found!" -ForegroundColor Yellow
    Write-Host "   (index.html, navigation.html, and resume HTMLs are excluded)" -ForegroundColor Gray
    exit
}

# Simple HTML to Markdown converter (basic conversion)
function Convert-HtmlToMarkdown {
    param([string]$html)

    # Remove HTML template wrapper (extract content between <body> tags)
    if ($html -match '(?s)<body[^>]*>(.*)</body>') {
        $html = $Matches[1]
    }

    # Remove .container divs and nav links
    $html = $html -replace '(?s)<div class="container">(.*)</div>', '$1'
    $html = $html -replace '(?s)<a[^>]*class="back-link"[^>]*>.*?</a>', ''

    # Headers
    $markdown = $html -replace '<h1[^>]*>(.*?)</h1>', '# $1'
    $markdown = $markdown -replace '<h2[^>]*>(.*?)</h2>', '## $1'
    $markdown = $markdown -replace '<h3[^>]*>(.*?)</h3>', '### $1'
    $markdown = $markdown -replace '<h4[^>]*>(.*?)</h4>', '#### $1'
    $markdown = $markdown -replace '<h5[^>]*>(.*?)</h5>', '##### $1'
    $markdown = $markdown -replace '<h6[^>]*>(.*?)</h6>', '###### $1'

    # Bold and Italic
    $markdown = $markdown -replace '<strong>(.*?)</strong>', '**$1**'
    $markdown = $markdown -replace '<b>(.*?)</b>', '**$1**'
    $markdown = $markdown -replace '<em>(.*?)</em>', '*$1*'
    $markdown = $markdown -replace '<i>(.*?)</i>', '*$1*'

    # Code
    $markdown = $markdown -replace '<code>(.*?)</code>', '`$1`'
    $markdown = $markdown -replace '(?s)<pre[^>]*><code[^>]*>(.*?)</code></pre>', '```$1```'
    $markdown = $markdown -replace '(?s)<pre[^>]*>(.*?)</pre>', '```$1```'

    # Links
    $markdown = $markdown -replace '<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', '[$2]($1)'

    # Lists
    $markdown = $markdown -replace '<li[^>]*>(.*?)</li>', '- $1'
    $markdown = $markdown -replace '(?s)<ul[^>]*>(.*?)</ul>', '$1'
    $markdown = $markdown -replace '(?s)<ol[^>]*>(.*?)</ol>', '$1'

    # Paragraphs
    $markdown = $markdown -replace '<p[^>]*>(.*?)</p>', '$1' + "`n`n"

    # Blockquotes
    $markdown = $markdown -replace '<blockquote[^>]*>(.*?)</blockquote>', '> $1'

    # Horizontal rules
    $markdown = $markdown -replace '<hr[^>]*>', '---'

    # Line breaks
    $markdown = $markdown -replace '<br[^>]*>', "`n"

    # Remove remaining HTML tags
    $markdown = $markdown -replace '<[^>]+>', ''

    # Decode HTML entities
    $markdown = $markdown -replace '&amp;', '&'
    $markdown = $markdown -replace '&lt;', '<'
    $markdown = $markdown -replace '&gt;', '>'
    $markdown = $markdown -replace '&quot;', '"'
    $markdown = $markdown -replace '&#39;', "'"
    $markdown = $markdown -replace '&nbsp;', ' '

    # Clean up extra whitespace
    $markdown = $markdown -replace '(?m)^\s+$', ''
    $markdown = $markdown -replace '\n{3,}', "`n`n"

    return $markdown.Trim()
}

$convertedCount = 0
$skippedCount = 0

foreach ($htmlFile in $htmlFiles) {
    $mdFileName = $htmlFile.BaseName + ".md"
    $mdFilePath = Join-Path -Path $coursePath -ChildPath $mdFileName

    # Skip if markdown already exists (unless -Overwrite specified)
    if ((Test-Path $mdFilePath) -and -not $Overwrite) {
        Write-Host "⏭️  Skipped: $($htmlFile.Name) (Markdown exists, use -Overwrite to replace)" -ForegroundColor Gray
        $skippedCount++
        continue
    }

    if ($Preview) {
        Write-Host "📄 Would convert: $($htmlFile.Name) → $mdFileName" -ForegroundColor Cyan
        continue
    }

    try {
        # Read HTML content
        $htmlContent = Get-Content -Path $htmlFile.FullName -Raw -Encoding UTF8

        # Convert HTML to Markdown
        $markdownContent = Convert-HtmlToMarkdown -html $htmlContent

        # Write Markdown file
        Set-Content -Path $mdFilePath -Value $markdownContent -Encoding UTF8

        Write-Host "✅ Converted: $($htmlFile.Name) → $mdFileName" -ForegroundColor Green
        $convertedCount++

    } catch {
        Write-Host "❌ Error converting $($htmlFile.Name): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
if ($Preview) {
    Write-Host "📋 Preview Complete!" -ForegroundColor Yellow
    Write-Host "   Would convert: $($htmlFiles.Count) files" -ForegroundColor Yellow
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
Write-Host "💡 Note: This uses basic HTML to Markdown conversion." -ForegroundColor Yellow
Write-Host "   For better results, install pandoc:" -ForegroundColor Yellow
Write-Host "   winget install pandoc" -ForegroundColor Gray
Write-Host "   Then use: pandoc input.html -o output.md" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  Warning: Complex tables and nested structures may need manual cleanup." -ForegroundColor Yellow