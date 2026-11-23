# 📚 Full-Stack AI Developer Course

**12 Weeks to ₹35-40 LPA | Chennai/Bengaluru**

---

## 🚀 Quick Start

### **1. Open Navigation**
```powershell
start navigation.html
```

### **2. Browse & Read**
- Click any file → "📖 VIEW HTML" to read beautiful formatted content
- Click "📝 EDIT MD" to open the markdown source file

### **3. Edit & Update**
```powershell
# Edit any markdown file in dev/ folder
code dev\Technical_Interview_QA_Resume_Projects.md

# After editing, sync to HTML
.\sync.ps1

# View updated HTML
start navigation.html
```

---

## 📂 Folder Structure

```
Course/
├── 📄 index.html              ← Interactive dashboard (START HERE)
├── 📄 navigation.html         ← File browser
├── 🔧 sync.ps1               ← Quick sync script
├── 📄 README.md              ← This file
│
├── 📂 dev/                    ← Edit files here (39 files)
│   ├── START_HERE.md
│   ├── Technical_Interview_QA_Resume_Projects.md
│   └── ... (all markdown files)
│
├── 📂 src/                  ← View files here (40 files)
│   ├── START_HERE.html
│   ├── Technical_Interview_QA_Resume_Projects.html
│   └── ... (all HTML files)
│
├── 📂 resume/                ← Resume PDFs (2 files)
│   ├── Karthikeyan SEKAR - AI-First Senior Full-Stack Engineer.pdf
│   └── Karthikeyan_Sekar_AI-First_FullStack_Engineer.pdf
│
└── 📂 utility/               ← Scripts & documentation (15 files)
    ├── convert-md-to-html-proper.py  ← Main converter
    ├── README.md                     ← Utility docs
    └── ... (deprecated scripts, documentation)
```

---

## ✅ Simple Rules

| Rule | Why |
|---|---|
| ✏️ **ALWAYS edit in `dev/` folder** | Markdown is the source of truth |
| 🔄 **ALWAYS run `.\sync.ps1` after editing** | Updates HTML from markdown |
| 👀 **ALWAYS view in `src/` folder** | Beautiful formatted versions |
| ❌ **NEVER edit HTML files directly** | They're auto-generated, changes will be lost |

---

## 🎯 Daily Workflow

```powershell
# 1. Edit markdown
code dev\Industry_Expectations_12Plus_Years.md

# 2. Save changes (Ctrl+S)

# 3. Sync to HTML
.\sync.ps1

# 4. View updated content
start navigation.html
# → Click the file → "VIEW HTML"
```

---

## 📊 What's Included

### **42 Total Files:**
- **39 Markdown files** in `dev/` folder (editable source)
- **40 HTML files** in `src/` folder (formatted view)
- **1 Interactive dashboard** (index.html)
- **1 File browser** (navigation.html)
- **2 Resume PDFs**

### **6 Modules:**
1. **Resume & LinkedIn** (Week 1)
2. **Technical Interview Mastery** (Week 2-4)
3. **System Design & Architecture**
4. **Technology Deep Dives**
5. **AI/ML & Full-Stack** (Week 5-10)
6. **Additional Study Guides**

---

## 🔧 Utilities

All scripts and documentation are in the **`utility/`** folder.

**Main converter:**
```powershell
python utility\convert-md-to-html-proper.py
```

**Or use the shortcut:**
```powershell
.\sync.ps1
```

**Auto-cleanup root folder:**
```powershell
.\utility\cleanup-root.ps1
```

See `utility/README.md` for details on all scripts.

---

## 📐 File Placement Rules

**Keep root folder clean!** Only 4 files allowed in root.

### **Where to create new files:**

| File Type | Location | Auto-Convert? |
|---|---|---|
| 📝 **Course content** | `dev/` folder | ✅ Yes (run `.\sync.ps1`) |
| 📄 **Utility docs** | `utility/` folder | ❌ No |
| 🔧 **Scripts** | `utility/` folder | ❌ No |
| 📄 **Resume PDFs** | `resume/` folder | ❌ No |

**Example:**
```powershell
# New course content
New-Item "dev\GraphQL_Interview_Guide.md"
.\sync.ps1  # Generates HTML

# New utility doc
New-Item "utility\NOTES_Analysis.md"
# No sync needed - stays in utility/
```

See `utility/FILE_PLACEMENT_RULES.md` for complete guide.

---

## 📖 Documentation

| File | Location | Purpose |
|---|---|---|
| **This file** | `README.md` | Quick start guide |
| **Utility docs** | `utility/README.md` | Scripts & tools reference |
| **START HERE** | `dev/START_HERE.md` | Detailed course navigation |
| **Course Syllabus** | `dev/COURSE_SYLLABUS.md` | 12-week schedule |

---

## 🎨 Features

✅ Beautiful HTML formatting with professional styling  
✅ Syntax-highlighted code blocks  
✅ Properly formatted tables  
✅ Responsive design  
✅ Clean, organized structure  
✅ One-command sync (`.\sync.ps1`)  
✅ All emojis and special characters work correctly  
✅ All links verified and working  

---

## 🆘 Troubleshooting

**Q: HTML doesn't show my changes?**  
A: Run `.\sync.ps1` to regenerate HTML from markdown

**Q: Where do I edit files?**  
A: Always edit in `dev/` folder, never in `src/` folder

**Q: Sync script not working?**  
A: Make sure Python is installed with `markdown` library:
```powershell
pip install markdown markdown-it-py pygments
```

**Q: Links not working in navigation?**  
A: Open `navigation.html` from the Course root folder

---

## 📝 Next Steps

1. ✅ **Open navigation.html** to browse all files
2. ✅ **Read START_HERE.md** for detailed navigation
3. ✅ **Review COURSE_SYLLABUS.md** for 12-week plan
4. ✅ **Start Module 1** (Resume & LinkedIn)

---

**Last Updated:** November 16, 2026  
**Status:** ✅ All files organized and working  
**Total Files:** 42 markdown/HTML + 2 PDF resumes

**Happy Learning! 🚀**
