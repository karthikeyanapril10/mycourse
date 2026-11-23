# Quick Sync Script - Converts MD to HTML with Progress Tracking
# This is a shortcut to the main converter in utility folder

Write-Host "Converting Markdown to HTML with Progress Tracking..." -ForegroundColor Cyan

# Call the converter with progress tracker
python "utility\convert-md-to-html-with-progress.py"

Write-Host ""
Write-Host "Done! All HTML files updated with progress checkboxes." -ForegroundColor Green
