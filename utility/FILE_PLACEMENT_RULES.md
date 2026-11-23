# 📋 File Placement Rules

**ALWAYS keep the root folder clean!**

---

## ✅ Where to Create New Files

### **📝 New Content Files (Course Material)**

**Location:** `dev/` folder  
**When:** Creating new course content, tutorials, guides, interview Q&A

**Example:**
```powershell
# Create new course content
New-Item "dev\New_Interview_Topic.md"

# After creating, run sync to generate HTML
.\sync.ps1
```

**Result:** 
- Creates `dev/New_Interview_Topic.md` ✓
- Generates `src/New_Interview_Topic.html` automatically ✓

---

### **📄 New Utility/Documentation Files**

**Location:** `utility/` folder  
**When:** Creating scripts, documentation, notes, analysis files

**Example:**
```powershell
# Create utility documentation
New-Item "utility\ANALYSIS_Notes.md"

# Create new script
New-Item "utility\custom-script.ps1"
```

**Result:**
- Stays in `utility/` ✓
- Does NOT get converted to HTML ✓
- Keeps root folder clean ✓

---

### **📄 New Resume PDFs**

**Location:** `resume/` folder  
**When:** Adding new resume versions

**Example:**
```powershell
# Save new resume PDF
Copy-Item "Downloads\Resume_v2.pdf" "resume\"
```

---

### **🚫 NEVER Create in Root**

**Root should ONLY contain:**
- `index.html` (dashboard)
- `navigation.html` (file browser)
- `README.md` (quick start)
- `sync.ps1` (sync script)

**Everything else goes in a subfolder!**

---

## 🧹 Auto-Cleanup

If files get created in root by mistake, run:

```powershell
.\utility\cleanup-root.ps1
```

**What it does:**
- ✓ Moves `.md` files → `utility/`
- ✓ Moves scripts → `utility/`
- ✓ Moves PDFs → `resume/`
- ✓ Moves test HTML → `utility/`
- ✓ Keeps only the 4 allowed files in root

---

## 📐 Decision Tree

```
New file to create?
│
├─ Course content (tutorial, guide, Q&A)?
│  └─ Create in dev/ → Run sync.ps1
│
├─ Documentation or notes?
│  └─ Create in utility/
│
├─ Script or tool?
│  └─ Create in utility/
│
├─ Resume PDF?
│  └─ Create in resume/
│
└─ Temporary test file?
   └─ Create in utility/ → Delete when done
```

---

## ✅ Examples

### **Example 1: New Interview Topic**
```powershell
# 1. Create in dev/
New-Item "dev\GraphQL_Interview_Guide.md"

# 2. Add content to the file
code "dev\GraphQL_Interview_Guide.md"

# 3. Sync to HTML
.\sync.ps1

# 4. Add to navigation.html manually (or regenerate it)
```

### **Example 2: New Analysis Document**
```powershell
# 1. Create in utility/ (NOT dev/)
New-Item "utility\ANALYSIS_Code_Quality.md"

# 2. This file stays in utility/
# No sync needed - it's not course content
```

### **Example 3: New Script**
```powershell
# 1. Create in utility/
New-Item "utility\custom-converter.py"

# 2. Document it in utility/README.md
```

---

## 🎯 Quick Reference

| File Type | Location | Auto-Convert? | Example |
|---|---|---|---|
| Course content MD | `dev/` | ✅ Yes (sync) | Interview guide |
| Utility docs MD | `utility/` | ❌ No | Analysis notes |
| Scripts | `utility/` | ❌ No | Python/PS1 scripts |
| Resume PDFs | `resume/` | ❌ No | Resume files |
| Generated HTML | `src/` | Auto-generated | Never create manually |

---

## ⚠️ Common Mistakes

❌ **DON'T:**
```powershell
# Creating utility docs in dev/ (will get converted to HTML unnecessarily)
New-Item "dev\NOTES_Random.md"

# Creating course content in root
New-Item "New_Tutorial.md"

# Creating scripts in root
New-Item "script.ps1"
```

✅ **DO:**
```powershell
# Course content → dev/
New-Item "dev\New_Tutorial.md"

# Utility docs → utility/
New-Item "utility\NOTES_Random.md"

# Scripts → utility/
New-Item "utility\script.ps1"
```

---

**Remember: Keep root clean! Only 4 files allowed there!** ✨

**Last Updated:** November 16, 2026
