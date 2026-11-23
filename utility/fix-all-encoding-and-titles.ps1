# Fix All Encoding Issues and Remove .md Extensions from Titles
# Processes all HTML and MD files in Course folder

$coursePath = "C:\Users\kasekar\GH\Course"
$encoding = [System.Text.Encoding]::UTF8

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Fixing Character Encoding Issues" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Character replacements mapping (garbled -> correct)
$charReplacements = @{
    'ðŸ"š' = '📚'
    'ðŸ"' = '🔍'
    'ðŸš€' = '🚀'
    'ðŸ"Š' = '📊'
    'â­' = '⭐'
    'ðŸ"Œ' = '📌'
    'ðŸŽ¯' = '🎯'
    'ðŸ"‹' = '📋'
    'ðŸ—ï¸' = '🗺️'
    'ðŸ"–' = '📖'
    'ðŸ"„' = '📄'
    'âœï¸' = '✍️'
    'ðŸŽ¤' = '🎤'
    'ðŸ"˜' = '📘'
    'ðŸ"—' = '📗'
    'ðŸ'»' = '💻'
    'ðŸ"…' = '📅'
    'ðŸ"§' = '🔧'
    'â˜ï¸' = '☁️'
    'ðŸ"Œ' = '🔌'
    'ðŸ'³' = '💳'
    'âš¡' = '⚡'
    'ðŸ"¨' = '📨'
    'â˜¸ï¸' = '☸️'
    'ðŸ"„' = '🔄'
    'ðŸ¤–' = '🤖'
    'ðŸ' = '🐍'
    'âš›ï¸' = '⚛️'
    'â‚¹' = '₹'
    'â†'' = '↑'
    'â†'' = '→'
    'Ã—' = '×'
}

# Get all HTML and MD files
$files = Get-ChildItem -Path $coursePath -Recurse -Include *.html,*.md -File
$totalFiles = $files.Count
$processedFiles = 0
$fixedFiles = 0

Write-Host "Found: $totalFiles files to process" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $files) {
    $processedFiles++
    $relativePath = $file.FullName.Replace($coursePath, "").TrimStart('\')

    Write-Host "[$processedFiles/$totalFiles] Processing: $relativePath" -ForegroundColor Gray

    try {
        # Read file with UTF-8 encoding
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        $changed = $false

        # Fix character encoding issues
        foreach ($garbled in $charReplacements.Keys) {
            if ($content -like "*$garbled*") {
                $content = $content -replace [regex]::Escape($garbled), $charReplacements[$garbled]
                $changed = $true
            }
        }

        # Remove .md extensions from visible titles (but NOT from href links)
        # Only for HTML files
        if ($file.Extension -eq '.html') {
            # Pattern 1: <h1>, <h2>, <h3> tags with .md in text
            $content = $content -replace '(<h[123]>)([^<]*?)\.md(<)', '$1$2$3'

            # Pattern 2: Title containing .md
            $content = $content -replace '(<title>)([^<]*?)\.md(<)', '$1$2$3'

            # Pattern 3: Card titles, navigation text with .md (but not in href="...")
            # This is complex - we need to be careful not to break links
            # Look for text between > and < that contains .md but isn't a link
            $lines = $content -split "`n"
            $newLines = @()

            foreach ($line in $lines) {
                # Skip lines with href= (don't touch actual links)
                if ($line -notlike '*href=*') {
                    # Remove .md from display text
                    $line = $line -replace '>([^<]*?)\.md<', '>$1<'

                    # Also fix underscored filenames to readable format
                    # e.g., "START_HERE" stays as is, but could be improved
                }
                $newLines += $line
            }

            $newContent = $newLines -join "`n"
            if ($newContent -ne $content) {
                $content = $newContent
                $changed = $true
            }
        }

        # For MD files - fix character encoding only (keep .md references as they're part of markdown syntax)

        # Save if changed
        if ($changed) {
            # Save with UTF-8 encoding (with BOM for better compatibility)
            [System.IO.File]::WriteAllText($file.FullName, $content, $encoding)
            Write-Host "  -> FIXED: Encoding/titles updated" -ForegroundColor Green
            $fixedFiles++
        } else {
            Write-Host "  -> OK: No changes needed" -ForegroundColor DarkGray
        }

    } catch {
        Write-Host "  -> ERROR: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Complete!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Total files processed: $processedFiles" -ForegroundColor Yellow
Write-Host "Files fixed: $fixedFiles" -ForegroundColor Green
Write-Host "Files unchanged: $($processedFiles - $fixedFiles)" -ForegroundColor Gray
Write-Host ""
Write-Host "All files now have:" -ForegroundColor Cyan
Write-Host "  - Correct UTF-8 encoding" -ForegroundColor White
Write-Host "  - Fixed emoji/special characters" -ForegroundColor White
Write-Host "  - Clean titles (no .md extensions in display)" -ForegroundColor White
