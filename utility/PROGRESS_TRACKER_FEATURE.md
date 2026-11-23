# ✅ Progress Tracker Feature

**Added:** November 16, 2026  
**Status:** ACTIVE

---

## 🎯 What It Does

Every HTML file now has an **interactive progress tracker** that:

✅ **Auto-detects sections** - Automatically creates checkboxes for every H2 and H3 heading  
✅ **Saves progress** - Remembers your checkboxes using browser localStorage  
✅ **Shows percentage** - Live progress percentage (e.g., "45%")  
✅ **Visual progress bar** - Beautiful gradient progress bar  
✅ **Click to scroll** - Click any section name to jump to that section  
✅ **Reset button** - Clear all progress for that page  
✅ **Collapsible** - Hide/show the full checklist  

---

## 📸 What It Looks Like

```
┌────────────────────────────────────────────────────┐
│ 📚 Your Progress                      45%  [Reset] │
│ ████████████░░░░░░░░░░░░░░░░░░░░░░░░░  [▼ Hide]   │
│                                                    │
│ ☑ Introduction                                     │
│ ☐ System Design Principles                        │
│ ☑   - Scalability                                  │
│ ☐   - Performance                                  │
│ ☐ Advanced Topics                                  │
│ ☐   - Microservices                                │
│ ☑   - Load Balancing                               │
└────────────────────────────────────────────────────┘
```

---

## 🎨 Features

### **1. Auto-Detection**
- Scans the HTML content for all H2 and H3 headings
- Creates a checkbox for each section
- H3 headings are indented under H2

### **2. LocalStorage**
- Each file has its own progress (saved separately)
- Survives browser refresh
- Survives closing and reopening browser
- Data stays on your computer only

### **3. Live Updates**
- Progress percentage updates as you check boxes
- Progress bar animates smoothly
- Completed items get a strikethrough effect

### **4. Click to Navigate**
- Click any section name to jump to that section
- Smooth scroll animation
- Great for navigating long documents

### **5. Reset Anytime**
- "Reset" button clears all checkboxes for that page
- Confirmation dialog prevents accidents
- Useful for reviewing material again

---

## 💾 How It Saves Progress

**Storage Method:** Browser localStorage  
**Key Format:** `course_progress_<file_name>`  
**Data Format:** JSON object with section IDs

**Example:**
```json
{
  "section-0": true,   // Checked
  "section-1": false,  // Unchecked
  "section-2": true    // Checked
}
```

**Storage Location:**
- **Chrome/Edge:** `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Local Storage`
- **Firefox:** `%APPDATA%\Mozilla\Firefox\Profiles\<profile>\webappsstore.sqlite`

**Data persists:**
- ✅ Across browser restarts
- ✅ Across computer restarts
- ❌ NOT synced across devices
- ❌ NOT backed up automatically

---

## 🔧 Usage

### **Daily Workflow:**

```powershell
# 1. Open any HTML file
start src\System_Design_Interview_Guide.html

# 2. Study a section

# 3. Check it off when done ✓

# 4. Progress saves automatically
```

### **Reset Progress:**
```
Click "Reset" button → Confirm → All checkboxes cleared
```

### **Hide/Show Checklist:**
```
Click "▼ Hide" → Checklist collapses
Click "▶ Show" → Checklist expands
```

---

## 🎯 Best Practices

### **For Learning:**
1. ✅ Check off sections **after you understand them**
2. ✅ Review unchecked sections regularly
3. ✅ Use reset to review material again later
4. ✅ Aim for 100% on important guides

### **For Interview Prep:**
1. ✅ Check sections as you master topics
2. ✅ Focus on unchecked high-priority areas
3. ✅ Track weak areas by leaving them unchecked
4. ✅ Reset before final review week

---

## 📊 Files Affected

**All 39 HTML files** in `src/` folder now have progress tracking:

- System Design guides ✓
- Interview Q&A documents ✓
- Technology deep-dives ✓
- Resume templates ✓
- Course materials ✓

---

## 🔄 How to Update

**After editing markdown:**

```powershell
# Regenerate HTML with progress tracker
.\sync.ps1
```

**Result:**
- HTML regenerated
- Progress tracker included
- **Your saved checkboxes remain intact** (localStorage persists)

---

## ⚠️ Important Notes

### **Progress is per-browser**
- If you use Chrome, progress saves in Chrome
- If you use Edge, it's separate progress
- Not synced between browsers

### **Progress is per-computer**
- Laptop progress ≠ Desktop progress
- Use same browser on same computer for consistency

### **Clearing browser data**
- Clearing cache: Progress **stays** ✓
- Clearing cookies: Progress **stays** ✓
- Clearing localStorage: Progress **deleted** ❌

### **Private/Incognito mode**
- Progress **does not save** in private browsing
- Use normal mode for persistent tracking

---

## 🎨 Customization

**Want to change colors?**  
Edit `utility\convert-md-to-html-with-progress.py`

**Progress bar colors:**
```python
background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
```

**Tracker background:**
```python
background: linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%);
```

**After editing, run:**
```powershell
.\sync.ps1
```

---

## 🆘 Troubleshooting

**Q: My progress disappeared!**  
A: Check if you:
- Cleared browser data (localStorage)
- Used a different browser
- Used private/incognito mode

**Q: Checkboxes don't save?**  
A: Check browser console for errors (F12)

**Q: Can I export my progress?**  
A: Not built-in, but you can:
1. F12 → Console
2. `localStorage` → View keys
3. Manually copy the data

**Q: Progress not showing?**  
A: Refresh the page (Ctrl+R)

---

## 📈 Future Enhancements (Ideas)

Possible future additions:
- Export progress to CSV
- Overall course completion dashboard
- Time spent tracking
- Study streak tracking
- Cross-device sync
- Notes per section

---

## ✅ Summary

**New workflow with progress tracking:**

```powershell
# 1. Study
start src\YourGuide.html

# 2. Check off sections as you complete them ✓

# 3. Watch your progress grow: 25% → 50% → 100%

# 4. Feel motivated! 🎉
```

**Your progress is automatically saved!**

---

**Last Updated:** November 16, 2026  
**Script:** `utility\convert-md-to-html-with-progress.py`  
**Trigger:** Automatically runs via `.\sync.ps1`
