# 📁 Course Folder Structure

**Reorganized:** November 16, 2026  
**Purpose:** Separate development (markdown) from view (HTML) files

---

## 🗂️ **New Folder Structure**

```
C:\Users\kasekar\GH\Course\
├── 📂 dev/              ← DEV FOLDER (Edit here)
│   ├── START_HERE.md
│   ├── Industry_Expectations_12Plus_Years.md
│   ├── NJQRT_Work_Context_Last_2.5_Years.md
│   ├── Technical_Interview_QA_Resume_Projects.md
│   └── ... (39 total markdown files)
│
├── 📂 src/            ← VIEW FOLDER (Auto-generated, don't edit)
│   ├── START_HERE.html
│   ├── Industry_Expectations_12Plus_Years.html
│   ├── NJQRT_Work_Context_Last_2.5_Years.html
│   └── ... (auto-synced from dev/)
│
├── 📂 utility/         ← SCRIPTS & TOOLS
│   ├── convert-md-to-html.ps1
│   ├── convert-html-to-md.ps1
│   ├── CONVERSION_SCRIPTS_README.md
│   └── ANALYSIS_Unwanted_Files.md
│
├── 📂 pdf/            ← RESUME PDFs
│   ├── Karthikeyan SEKAR - AI-First Senior Full-Stack Engineer.pdf
│   └── Karthikeyan_Sekar_AI-First_FullStack_Engineer.pdf
│
├── 📄 index.html          ← Interactive Dashboard (ROOT)
├── 📄 navigation.html     ← File Browser (ROOT)
├── 📄 sync-md-to-html.ps1 ← AUTO-SYNC SCRIPT ⭐
└── 📄 README_FOLDER_STRUCTURE.md (this file)
```

---

## 🎯 **Simple Rules**

### **1️⃣ ALWAYS Edit in `dev/` Folder**
```powershell
# Edit markdown files
code "dev\Technical_Interview_QA_Resume_Projects.md"
```

**Why?** `dev/` is the source of truth. HTML is auto-generated.

---

### **2️⃣ NEVER Edit in `src/` Folder**
```powershell
# ❌ DON'T DO THIS
code "src\Technical_Interview_QA_Resume_Projects.html"
```

**Why?** HTML files are auto-generated and will be overwritten when you sync.

---

### **3️⃣ AUTO-SYNC After Editing**
```powershell
# After editing dev/ files, sync to src/
.\sync-md-to-html.ps1
```

**Result:** Your changes in `dev/` are converted to `src/` automatically!

---

## 🔄 **Workflow: Edit → Sync → View**

### **Step 1: Edit Markdown (in `dev/` folder)**
```powershell
# Example: Update interview questions
code "dev\Technical_Interview_QA_Resume_Projects.md"

# Make your changes...
# Save (Ctrl+S)
```

---

### **Step 2: Sync to HTML (run sync script)**
```powershell
# Option A: Convert only changed files (fast)
.\sync-md-to-html.ps1

# Option B: Convert all files (force)
.\sync-md-to-html.ps1 -All

# Option C: Watch mode (auto-sync on save) ⭐ RECOMMENDED
.\sync-md-to-html.ps1 -Watch
```

**Watch Mode** = Runs continuously, auto-converts whenever you save a `.md` file!

---

### **Step 3: View HTML (in browser)**
```powershell
# Open navigation to browse all HTML files
start navigation.html

# Or open a specific HTML file directly
start "src\Technical_Interview_QA_Resume_Projects.html"
```

---

## 🚀 **Quick Start Commands**

### **Daily Workflow (Recommended)**

```powershell
# 1. Start watch mode in one terminal (keeps running)
.\sync-md-to-html.ps1 -Watch

# 2. Edit markdown files in another terminal/VS Code
code "dev\START_HERE.md"

# 3. Save your changes (Ctrl+S)
# → Watch mode auto-converts to HTML!

# 4. Refresh browser to see changes
# → Open navigation.html and click "VIEW HTML"
```

---

### **One-Time Sync (No Watch Mode)**

```powershell
# 1. Edit markdown
code "dev\Industry_Expectations_12Plus_Years.md"

# 2. Sync manually
.\sync-md-to-html.ps1

# 3. View HTML
start "src\Industry_Expectations_12Plus_Years.html"
```

---

## 📊 **File Counts**

| Folder | Count | Purpose |
|---|---|---|
| `dev/` | 39 files | **Source of truth** (edit here) |
| `src/` | 39 files | **Auto-generated** (view only) |
| `utility/` | 5 files | Scripts & analysis |
| `pdf/` | 2 files | Final resume PDFs |
| **root/** | 3 files | index.html, navigation.html, sync script |

**Total:** 88 files

---

## 🔧 **Script Reference**

### **`sync-md-to-html.ps1`** ⭐ **PRIMARY SCRIPT**

```powershell
# Convert only changed files
.\sync-md-to-html.ps1

# Convert all files (force)
.\sync-md-to-html.ps1 -All

# Watch mode (auto-sync on save)
.\sync-md-to-html.ps1 -Watch
```

**Features:**
- ✅ Only converts files that changed (fast!)
- ✅ Tracks timestamps (skips up-to-date files)
- ✅ Watch mode for auto-sync
- ✅ Beautiful HTML styling
- ✅ Metadata footer (source filename, timestamp)

---

### **Old Scripts (Moved to `utility/`)**

```powershell
# Old conversion scripts (still work, but use sync-md-to-html.ps1 instead)
.\utility\convert-md-to-html.ps1
.\utility\convert-html-to-md.ps1
```

---

## 🎨 **What HTML Files Look Like**

Each HTML file includes:
- ✅ **Back to Navigation** link (top)
- ✅ **Metadata footer** (source file, last updated)
- ✅ **Beautiful styling** (gradients, tables, code highlighting)
- ✅ **Mobile-friendly** layout

**Example:**
```html
📄 Source: dev/START_HERE.md | 🕐 Last Updated: 2026-11-16 18:30:15
```

---

## ⚠️ **Important Rules**

### **DO:**
- ✅ Edit files in `dev/` folder
- ✅ Run `sync-md-to-html.ps1` after editing
- ✅ View HTML files in `src/` folder
- ✅ Use watch mode (`-Watch`) for auto-sync

### **DON'T:**
- ❌ Edit files in `src/` folder (will be overwritten!)
- ❌ Delete `dev/` files (source of truth)
- ❌ Manually create HTML files (use sync script)

---

## 🆘 **Troubleshooting**

### **Q: I edited an HTML file but changes disappeared!**
**A:** HTML files are auto-generated. Edit the `.md` file in `dev/` folder instead, then run `sync-md-to-html.ps1`.

---

### **Q: Watch mode isn't detecting my changes**
**A:** Make sure you're editing files in the `dev/` folder (not `src/` folder). Save the file (Ctrl+S) and wait 1-2 seconds.

---

### **Q: How do I stop watch mode?**
**A:** Press `Ctrl+C` in the terminal running the watch script.

---

### **Q: Can I edit files directly in VS Code?**
**A:** Yes! Open the `dev/` folder in VS Code:
```powershell
code dev\
```

Then start watch mode in a terminal:
```powershell
.\sync-md-to-html.ps1 -Watch
```

Now every time you save a file (Ctrl+S), it auto-converts to HTML!

---

## 🎯 **Benefits of This Structure**

### **Before (Old Structure):**
- ❌ `.md` and `.html` files mixed together (confusing)
- ❌ Hard to know which files to edit
- ❌ No auto-sync (manual conversion every time)

### **After (New Structure):**
- ✅ Clear separation: `dev/` = edit, `src/` = view
- ✅ Auto-sync with watch mode
- ✅ Beautiful HTML styling for all files
- ✅ Easy to maintain (edit one place, HTML auto-updates)

---

## 📝 **Example: Full Workflow**

Let's say you want to add a new question to the interview Q&A:

```powershell
# 1. Start watch mode (one-time setup)
.\sync-md-to-html.ps1 -Watch

# 2. Open markdown file for editing
code "dev\Technical_Interview_QA_Resume_Projects.md"

# 3. Add your new question
# (Type, edit, save with Ctrl+S)

# 4. Watch mode auto-converts!
# Output: ✅ Converted: Technical_Interview_QA_Resume_Projects.md → src\...

# 5. View the HTML version
start navigation.html
# Click "Technical Interview Q&A" → "VIEW HTML"

# 6. Refresh browser to see your new question!
```

**That's it!** No manual conversion needed with watch mode!

---

## 🚀 **Next Steps**

1. **Open navigation.html** → Bookmark it
2. **Start watch mode** → `.\sync-md-to-html.ps1 -Watch`
3. **Edit dev/ files** → Changes auto-sync to src/
4. **View src/ files** → Beautiful, styled content

---

**You're all set! Happy editing! 💪**