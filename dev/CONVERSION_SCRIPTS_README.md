# 🔄 Markdown ↔ HTML Conversion Scripts

**Location:** `C:\Users\kasekar\GH\Course\`  
**Created:** November 16, 2026

---

## 📋 **What These Scripts Do**

### **1. `convert-md-to-html.ps1`**
- Converts all `.md` files → `.html` files
- Creates beautiful HTML versions with styling
- Preserves original `.md` files (doesn't delete them)
- Adds "Back to Navigation" link to each HTML page

### **2. `convert-html-to-md.ps1`**
- Converts HTML files → `.md` files for editing
- Excludes navigation/resume HTMLs (index.html, navigation.html, resume HTMLs)
- Useful for editing HTML content back to markdown
- Preserves original `.html` files

---

## 🚀 **How to Use**

### **Convert All Markdown to HTML**

```powershell
# Preview what will be converted (doesn't actually convert)
.\convert-md-to-html.ps1 -Preview

# Convert all .md files to .html
.\convert-md-to-html.ps1

# Convert and overwrite existing HTML files
.\convert-md-to-html.ps1 -Overwrite
```

**Result:** All 37 markdown files become HTML files with beautiful styling

---

### **Convert HTML Back to Markdown**

```powershell
# Preview what will be converted
.\convert-html-to-md.ps1 -Preview

# Convert HTML files to .md (excludes index.html, navigation.html, resume HTMLs)
.\convert-html-to-md.ps1

# Convert and overwrite existing .md files
.\convert-html-to-md.ps1 -Overwrite
```

**Result:** HTML content files are converted back to markdown for editing

---

## 📊 **Current Folder Status**

**Before conversion:**
- 37 `.md` files (content)
- 4 `.html` files (index.html, navigation.html, 2 resume HTMLs)
- 2 `.pdf` files (final resumes)

**After running `convert-md-to-html.ps1`:**
- 37 `.md` files (original content, preserved)
- 41 `.html` files (4 original + 37 new from conversion)
- 2 `.pdf` files (unchanged)

**Total:** 80 files (37 md + 41 html + 2 pdf)

---

## 🎯 **Use Cases**

### **Use Case 1: Create HTML Version of Entire Course**

**Why:** Browse all course content as HTML pages (better formatting, clickable links)

```powershell
# Convert all markdown to HTML
.\convert-md-to-html.ps1

# Result: Every .md file now has a matching .html file
# Open navigation.html → Click any file → Opens as beautiful HTML
```

---

### **Use Case 2: Edit Content and Re-Generate HTML**

**Why:** You want to update content but view it as HTML

```powershell
# 1. Edit a markdown file
code "Technical_Interview_QA_Resume_Projects.md"

# 2. Re-convert just that file to HTML
.\convert-md-to-html.ps1 -Overwrite

# 3. Refresh your browser to see updated HTML
```

---

### **Use Case 3: Convert HTML Back to Markdown for Editing**

**Why:** Someone sent you HTML and you want to edit it as markdown

```powershell
# Convert HTML content files back to markdown
.\convert-html-to-md.ps1 -Overwrite

# Edit the markdown
code "SomeFile.md"

# Re-convert to HTML when done
.\convert-md-to-html.ps1 -Overwrite
```

---

## 🎨 **HTML Styling**

Each converted HTML file includes:
- ✅ Beautiful gradient background
- ✅ Responsive container (max-width: 1000px)
- ✅ Syntax highlighting for code blocks
- ✅ Table styling (alternating row colors)
- ✅ "Back to Navigation" link
- ✅ Mobile-friendly layout

**Preview:** Open any converted HTML file to see the styling

---

## ⚠️ **Important Notes**

### **What Gets Excluded from HTML → MD Conversion?**

These files are **skipped** (they're not content files):
- `index.html` (interactive dashboard)
- `navigation.html` (file browser)
- `Karthikeyan_Sekar_Resume_Beautiful.html` (resume)
- `Karthikeyan_Sekar_Resume_ATS_Optimized.html` (resume)

### **Limitations of Basic Conversion**

The scripts use **basic markdown/HTML conversion**:
- ✅ Handles: headers, bold, italic, links, lists, code, tables
- ⚠️ May struggle with: complex nested structures, custom HTML/CSS, embedded images

**For better conversion, install Pandoc:**
```powershell
# Install pandoc (one-time setup)
winget install pandoc

# Convert with pandoc (much better quality)
pandoc input.md -o output.html
pandoc input.html -o output.md
```

---

## 📁 **File Organization After Conversion**

```
C:\Users\kasekar\GH\Course\
├── 📄 Markdown Files (.md)
│   ├── START_HERE.md
│   ├── Industry_Expectations_12Plus_Years.md
│   ├── NJQRT_Work_Context_Last_2.5_Years.md
│   ├── Technical_Interview_QA_Resume_Projects.md
│   └── ... (37 total)
│
├── 🌐 HTML Files (.html)
│   ├── index.html ⭐ (interactive dashboard)
│   ├── navigation.html ⭐ (file browser)
│   ├── START_HERE.html (converted from .md)
│   ├── Industry_Expectations_12Plus_Years.html (converted from .md)
│   └── ... (41 total)
│
├── 📄 PDF Files (.pdf)
│   ├── Karthikeyan SEKAR - AI-First Senior Full-Stack Engineer.pdf
│   └── Karthikeyan_Sekar_AI-First_FullStack_Engineer.pdf
│
└── 🔧 Scripts
    ├── convert-md-to-html.ps1
    ├── convert-html-to-md.ps1
    ├── CONVERSION_SCRIPTS_README.md (this file)
    └── ANALYSIS_Unwanted_Files.md
```

---

## 🎯 **Quick Reference**

| Task | Command |
|---|---|
| **Preview MD → HTML** | `.\convert-md-to-html.ps1 -Preview` |
| **Convert MD → HTML** | `.\convert-md-to-html.ps1` |
| **Overwrite existing HTML** | `.\convert-md-to-html.ps1 -Overwrite` |
| **Preview HTML → MD** | `.\convert-html-to-md.ps1 -Preview` |
| **Convert HTML → MD** | `.\convert-html-to-md.ps1` |
| **Overwrite existing MD** | `.\convert-html-to-md.ps1 -Overwrite` |

---

## 💡 **Pro Tips**

1. **Always preview first** (`-Preview`) to see what will be converted
2. **Keep both .md and .html** (disk space is cheap, flexibility is valuable)
3. **Edit markdown, not HTML** (easier to maintain)
4. **Re-convert after editing** (keep HTML versions in sync)
5. **Use Pandoc for production** (better quality than basic conversion)

---

## 🆘 **Troubleshooting**

### **Script won't run?**
```powershell
# Enable script execution (run once)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then try again
.\convert-md-to-html.ps1
```

### **HTML looks broken?**
- Complex markdown features (nested lists, tables) may need manual cleanup
- Use Pandoc for better conversion: `pandoc input.md -o output.html`

### **Want to convert just one file?**
Edit the script and add a `-Name` parameter, or just manually run:
```powershell
pandoc "Technical_Interview_QA_Resume_Projects.md" -o "Technical_Interview_QA_Resume_Projects.html"
```

---

## 📞 **Need Help?**

- Read script comments: Both scripts have detailed inline comments
- Check output messages: Scripts tell you exactly what they're doing
- Use `-Preview` first: See what will happen before it happens

---

**Happy converting! 🚀**