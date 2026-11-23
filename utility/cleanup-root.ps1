# Auto-Cleanup Root Folder
# Moves misplaced files to correct locations

$courseRoot = "C:\Users\kasekar\GH\Course"

Write-Host "🧹 Cleaning up root folder..." -ForegroundColor Cyan
Write-Host ""

$movedFiles = 0

# Get all files in root (except allowed ones)
$allowedFiles = @('index.html', 'navigation.html', 'README.md', 'sync.ps1')
$rootFiles = Get-ChildItem -Path $courseRoot -File

foreach ($file in $rootFiles) {
    if ($file.Name -notin $allowedFiles) {
        $moved = $false

        # Rule 1: Move .md files (utility docs) to utility/
        if ($file.Extension -eq '.md') {
            $dest = "$courseRoot\utility\$($file.Name)"
            Move-Item -Path $file.FullName -Destination $dest -Force
            Write-Host "✓ Moved $($file.Name) → utility/" -ForegroundColor Green
            $moved = $true
        }

        # Rule 2: Move scripts (.ps1, .py, .sh) to utility/
        elseif ($file.Extension -in @('.ps1', '.py', '.sh', '.bat')) {
            $dest = "$courseRoot\utility\$($file.Name)"
            Move-Item -Path $file.FullName -Destination $dest -Force
            Write-Host "✓ Moved $($file.Name) → utility/" -ForegroundColor Green
            $moved = $true
        }

        # Rule 3: Move PDF files to resume/
        elseif ($file.Extension -eq '.pdf') {
            $dest = "$courseRoot\resume\$($file.Name)"
            Move-Item -Path $file.FullName -Destination $dest -Force
            Write-Host "✓ Moved $($file.Name) → resume/" -ForegroundColor Green
            $moved = $true
        }

        # Rule 4: Move HTML files (non-index, non-navigation) to utility/
        elseif ($file.Extension -eq '.html') {
            $dest = "$courseRoot\utility\$($file.Name)"
            Move-Item -Path $file.FullName -Destination $dest -Force
            Write-Host "✓ Moved $($file.Name) → utility/" -ForegroundColor Green
            $moved = $true
        }

        if ($moved) { $movedFiles++ }
    }
}

Write-Host ""
if ($movedFiles -eq 0) {
    Write-Host "✨ Root folder is already clean!" -ForegroundColor Green
} else {
    Write-Host "✓ Cleaned up $movedFiles files" -ForegroundColor Green
}

Write-Host ""
Write-Host "Current root files:" -ForegroundColor Yellow
Get-ChildItem -Path $courseRoot -File | Select-Object Name | Format-Table -HideTableHeaders
