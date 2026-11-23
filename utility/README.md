# Utility Folder - Scripts & Documentation

This folder contains all conversion scripts, documentation, and utility files.

---

## 📂 **What's in This Folder**

### **🔧 Active Scripts (Use These)**

| File | Purpose | How to Use |
|---|---|---|
| **convert-md-to-html-proper.py** | ⭐ Main converter - Converts all MD → HTML with proper formatting | `python utility\convert-md-to-html-proper.py` |

**OR use the shortcut in root:**
```powershell
.\sync.ps1
```

---

### **📄 Documentation Files**

| File | Description |
|---|---|
| **README_FOLDER_STRUCTURE.md** | Complete guide to the folder structure and workflow |
| **ENCODING_FIXES_COMPLETE.md** | Summary of all encoding fixes done on Nov 16, 2026 |
| **LINKS_FIXED_AND_TESTED.md** | Link verification results |
| **REORGANIZATION_COMPLETE.md** | Original reorganization summary |

---

### **🗑️ Deprecated/Old Scripts (Don't Use)**

| File | Status | Why Deprecated |
|---|---|---|
| sync-md-to-html-simple.ps1 | ❌ Deprecated | Used regex only - broken formatting |
| sync-md-to-html-fixed.ps1 | ❌ Deprecated | Partial fix - still had issues |
| sync-md-to-html.ps1 | ❌ Deprecated | Watch mode version - had errors |
| fix-all-encoding-and-titles.ps1 | ❌ Deprecated | One-time fix - already applied |
| fix_encoding.py | ❌ Deprecated | One-time fix - already applied |
| fix-md-encoding.sh | ❌ Deprecated | One-time fix - already applied |

**These files are kept for reference only. Don't use them!**

---

### **📊 Analysis Files**

| File | Description |
|---|---|
| **ANALYSIS_Unwanted_Files.md** | File analysis from initial cleanup |
| **CONVERSION_SCRIPTS_README.md** | Old conversion documentation |

---

## 🚀 **Daily Workflow**

### **To Update HTML Files After Editing Markdown:**

**Option 1: Use the root shortcut (Easiest)**
```powershell
.\sync.ps1
```

**Option 2: Run converter directly**
```powershell
python utility\convert-md-to-html-proper.py
```

**Option 3: From utility folder**
```powershell
cd utility
python convert-md-to-html-proper.py
```

---

## 📝 **What Each Script Does**

### **convert-md-to-html-proper.py ⭐**

**What it does:**
- Reads all `.md` files from `dev/` folder
- Converts them to beautiful HTML using Python markdown library
- Handles ALL markdown features:
  - ✅ Tables
  - ✅ Syntax-highlighted code blocks
  - ✅ Proper lists (nested, ordered, unordered)
  - ✅ Blockquotes
  - ✅ Links, images, everything
- Outputs to `src/` folder
- Adds professional styling and formatting

**Features:**
- Proper markdown parser (not regex)
- Beautiful gradient styling
- Responsive design
- Syntax highlighting for code
- Professional table formatting

---

## 🎯 **Quick Reference**

### **Root Folder Structure:**
```
Course/
├── index.html              ← Dashboard
├── navigation.html         ← File browser
├── sync.ps1               ← Quick sync shortcut
│
├── dev/                    ← Edit here
│   └── (39 markdown files)
│
├── src/                  ← View here
│   └── (39 HTML files)
│
├── utility/               ← Scripts & docs (THIS FOLDER)
│   ├── convert-md-to-html-proper.py  ← Main converter
│   ├── README.md                     ← This file
│   └── (documentation files)
│
└── pdf/                   ← Resume PDFs
```

---

## ⚠️ **Important Notes**

1. **Always use `convert-md-to-html-proper.py`** - It's the only one that works correctly
2. **Don't use the old PowerShell scripts** - They have encoding/formatting issues
3. **Edit in `dev/` folder** - Never edit HTML files directly
4. **Run sync after editing** - Your changes won't show in HTML until you sync
5. **Keep this folder organized** - Don't add new files to root, put them here

---

## 🔄 **If You Need to Regenerate Everything:**

```powershell
# From Course root
.\sync.ps1

# This will regenerate all 39 HTML files from markdown
```

---

**Last Updated:** November 16, 2026  
**Total Scripts:** 11 files  
**Active Scripts:** 1 (convert-md-to-html-proper.py)  
**Deprecated:** 6 (kept for reference)
