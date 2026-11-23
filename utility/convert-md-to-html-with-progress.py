#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Proper Markdown to HTML converter with PROGRESS TRACKING
Adds interactive checkboxes that save progress to browser localStorage
"""

import markdown
from pathlib import Path
from datetime import datetime
import re

# Markdown extensions for full feature support
EXTENSIONS = [
    'extra',          # Tables, fenced code blocks, footnotes
    'codehilite',     # Syntax highlighting
    'toc',            # Table of contents
    'nl2br',          # Newline to <br>
    'sane_lists',     # Better list handling
]

# HTML template with progress tracker
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.8;
            color: #333;
            background: #f5f7fa;
            padding: 20px;
        }}

        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 60px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
        }}

        .back-link {{
            display: inline-block;
            margin-bottom: 30px;
            padding: 10px 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 500;
            transition: transform 0.2s, box-shadow 0.2s;
        }}

        .back-link:hover {{
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.4);
        }}

        .metadata {{
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 16px 24px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 0.9em;
            color: #666;
            border-left: 4px solid #667eea;
        }}

        /* PROGRESS TRACKER STYLES */
        .progress-tracker {{
            background: linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%);
            border: 2px solid #667eea;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 40px;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.15);
        }}

        .progress-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            flex-wrap: wrap;
            gap: 15px;
        }}

        .progress-title {{
            font-size: 1.3em;
            font-weight: 700;
            color: #667eea;
            display: flex;
            align-items: center;
            gap: 10px;
        }}

        .progress-stats {{
            display: flex;
            align-items: center;
            gap: 15px;
        }}

        .progress-percentage {{
            font-size: 1.5em;
            font-weight: 700;
            color: #764ba2;
        }}

        .progress-bar-container {{
            height: 12px;
            background: #e9ecef;
            border-radius: 20px;
            overflow: hidden;
            margin-bottom: 20px;
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.1);
        }}

        .progress-bar-fill {{
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            transition: width 0.5s ease;
            border-radius: 20px;
        }}

        .reset-btn {{
            padding: 8px 20px;
            background: #dc3545;
            color: white;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
            font-size: 0.9em;
            transition: all 0.2s;
        }}

        .reset-btn:hover {{
            background: #c82333;
            transform: translateY(-1px);
            box-shadow: 0 4px 10px rgba(220, 53, 69, 0.3);
        }}

        .progress-items {{
            max-height: 400px;
            overflow-y: auto;
            padding-right: 10px;
        }}

        .progress-items::-webkit-scrollbar {{
            width: 8px;
        }}

        .progress-items::-webkit-scrollbar-track {{
            background: #f1f1f1;
            border-radius: 10px;
        }}

        .progress-items::-webkit-scrollbar-thumb {{
            background: #667eea;
            border-radius: 10px;
        }}

        .progress-item {{
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 10px;
            margin-bottom: 8px;
            background: white;
            border-radius: 8px;
            transition: all 0.2s;
        }}

        .progress-item:hover {{
            background: #f8f9fa;
            transform: translateX(5px);
        }}

        .progress-item.completed {{
            opacity: 0.7;
        }}

        .progress-checkbox {{
            width: 20px;
            height: 20px;
            cursor: pointer;
            margin-top: 2px;
            flex-shrink: 0;
        }}

        .progress-label {{
            cursor: pointer;
            font-size: 0.95em;
            line-height: 1.5;
            color: #495057;
            flex-grow: 1;
        }}

        .progress-item.completed .progress-label {{
            text-decoration: line-through;
            color: #999;
        }}

        .toggle-progress {{
            background: none;
            border: none;
            color: #667eea;
            cursor: pointer;
            font-weight: 600;
            font-size: 0.9em;
            padding: 5px 10px;
            border-radius: 4px;
            transition: background 0.2s;
        }}

        .toggle-progress:hover {{
            background: rgba(102, 126, 234, 0.1);
        }}

        .progress-items.collapsed {{
            display: none;
        }}

        /* CONTENT STYLES */
        h1 {{
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 20px;
            padding-bottom: 20px;
            border-bottom: 4px solid #667eea;
            font-weight: 700;
        }}

        h2 {{
            color: #764ba2;
            font-size: 2em;
            margin-top: 50px;
            margin-bottom: 20px;
            font-weight: 600;
            padding-bottom: 10px;
            border-bottom: 2px solid #e9ecef;
        }}

        h3 {{
            color: #495057;
            font-size: 1.5em;
            margin-top: 35px;
            margin-bottom: 15px;
            font-weight: 600;
        }}

        h4 {{
            color: #666;
            font-size: 1.25em;
            margin-top: 25px;
            margin-bottom: 12px;
            font-weight: 600;
        }}

        p {{
            margin-bottom: 20px;
            line-height: 1.8;
        }}

        ul, ol {{
            margin: 20px 0;
            padding-left: 40px;
        }}

        li {{
            margin-bottom: 12px;
            line-height: 1.7;
        }}

        code {{
            background: #f4f5f7;
            padding: 3px 8px;
            border-radius: 4px;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            font-size: 0.9em;
            color: #c7254e;
            border: 1px solid #e1e4e8;
        }}

        pre {{
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 24px;
            border-radius: 8px;
            overflow-x: auto;
            margin: 25px 0;
            border: 1px solid #444;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}

        pre code {{
            background: none;
            color: inherit;
            padding: 0;
            border: none;
            font-size: 0.95em;
            line-height: 1.6;
        }}

        blockquote {{
            border-left: 5px solid #667eea;
            padding: 15px 25px;
            margin: 25px 0;
            background: #f8f9fa;
            border-radius: 0 8px 8px 0;
            color: #495057;
            font-style: italic;
        }}

        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 30px 0;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }}

        th, td {{
            border: 1px solid #dee2e6;
            padding: 14px 18px;
            text-align: left;
        }}

        th {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 0.5px;
        }}

        tr:nth-child(even) {{
            background: #f8f9fa;
        }}

        tr:hover {{
            background: #e9ecef;
            transition: background 0.2s;
        }}

        a {{
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
            border-bottom: 1px solid transparent;
            transition: border-bottom 0.2s;
        }}

        a:hover {{
            border-bottom: 1px solid #667eea;
        }}

        hr {{
            border: none;
            border-top: 2px solid #e9ecef;
            margin: 40px 0;
        }}

        strong {{
            color: #2c3e50;
            font-weight: 600;
        }}

        em {{
            color: #495057;
        }}

        img {{
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 25px 0;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }}

        /* Responsive */
        @media (max-width: 768px) {{
            .container {{
                padding: 30px 20px;
            }}

            h1 {{
                font-size: 2em;
            }}

            h2 {{
                font-size: 1.6em;
            }}

            .progress-header {{
                flex-direction: column;
                align-items: flex-start;
            }}

            .progress-stats {{
                width: 100%;
                justify-content: space-between;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <a href="../navigation.html" class="back-link">&larr; Back to Navigation</a>

        <div class="metadata">
            <strong>Source:</strong> dev/{filename} &nbsp;|&nbsp; <strong>Updated:</strong> {timestamp}
        </div>

        <!-- PROGRESS TRACKER -->
        <div class="progress-tracker">
            <div class="progress-header">
                <div class="progress-title">
                    <span>📚</span>
                    <span>Your Progress</span>
                </div>
                <div class="progress-stats">
                    <span class="progress-percentage" id="progress-pct">0%</span>
                    <button class="reset-btn" onclick="resetProgress()">Reset</button>
                    <button class="toggle-progress" onclick="toggleProgressList()">▼ Hide</button>
                </div>
            </div>
            <div class="progress-bar-container">
                <div class="progress-bar-fill" id="progress-bar" style="width: 0%"></div>
            </div>
            <div class="progress-items" id="progress-items">
                <!-- Checkboxes will be generated by JavaScript -->
            </div>
        </div>

        <!-- MAIN CONTENT -->
        <div class="content">
{content}
        </div>
    </div>

    <script>
        // Progress Tracker JavaScript
        const STORAGE_KEY = 'course_progress_{file_id}';

        // Extract all H2 and H3 headings from content
        function extractSections() {{
            const content = document.querySelector('.content');
            const headings = content.querySelectorAll('h2, h3');
            const sections = [];

            headings.forEach((heading, index) => {{
                const level = heading.tagName === 'H2' ? 2 : 3;
                const text = heading.textContent.trim();
                const id = `section-${{index}}`;

                // Add ID to heading for linking
                heading.id = id;

                sections.push({{
                    id: id,
                    text: text,
                    level: level
                }});
            }});

            return sections;
        }}

        // Load saved progress from localStorage
        function loadProgress() {{
            const saved = localStorage.getItem(STORAGE_KEY);
            return saved ? JSON.parse(saved) : {{}};
        }}

        // Save progress to localStorage
        function saveProgress(progress) {{
            localStorage.setItem(STORAGE_KEY, JSON.stringify(progress));
        }}

        // Calculate progress percentage
        function calculateProgress() {{
            const checkboxes = document.querySelectorAll('.progress-checkbox');
            const total = checkboxes.length;
            if (total === 0) return 0;

            const completed = Array.from(checkboxes).filter(cb => cb.checked).length;
            return Math.round((completed / total) * 100);
        }}

        // Update progress display
        function updateProgressDisplay() {{
            const percentage = calculateProgress();
            document.getElementById('progress-pct').textContent = percentage + '%';
            document.getElementById('progress-bar').style.width = percentage + '%';

            // Update completed class on items
            document.querySelectorAll('.progress-item').forEach(item => {{
                const checkbox = item.querySelector('.progress-checkbox');
                if (checkbox.checked) {{
                    item.classList.add('completed');
                }} else {{
                    item.classList.remove('completed');
                }}
            }});
        }}

        // Toggle checkbox
        function toggleCheckbox(sectionId) {{
            const checkbox = document.getElementById('cb-' + sectionId);
            const progress = loadProgress();

            progress[sectionId] = checkbox.checked;
            saveProgress(progress);
            updateProgressDisplay();
        }}

        // Reset all progress
        function resetProgress() {{
            if (confirm('Reset all progress for this page?')) {{
                localStorage.removeItem(STORAGE_KEY);
                document.querySelectorAll('.progress-checkbox').forEach(cb => {{
                    cb.checked = false;
                }});
                updateProgressDisplay();
            }}
        }}

        // Toggle progress list visibility
        function toggleProgressList() {{
            const list = document.getElementById('progress-items');
            const btn = document.querySelector('.toggle-progress');

            if (list.classList.contains('collapsed')) {{
                list.classList.remove('collapsed');
                btn.textContent = '▼ Hide';
            }} else {{
                list.classList.add('collapsed');
                btn.textContent = '▶ Show';
            }}
        }}

        // Initialize progress tracker
        function initProgressTracker() {{
            const sections = extractSections();
            const progress = loadProgress();
            const container = document.getElementById('progress-items');

            if (sections.length === 0) {{
                container.innerHTML = '<p style="color: #999; text-align: center; padding: 20px;">No sections found</p>';
                return;
            }}

            sections.forEach(section => {{
                const item = document.createElement('div');
                item.className = 'progress-item';

                const checkbox = document.createElement('input');
                checkbox.type = 'checkbox';
                checkbox.className = 'progress-checkbox';
                checkbox.id = 'cb-' + section.id;
                checkbox.checked = progress[section.id] || false;
                checkbox.onchange = () => toggleCheckbox(section.id);

                const label = document.createElement('label');
                label.className = 'progress-label';
                label.htmlFor = 'cb-' + section.id;
                label.textContent = section.text;
                label.style.paddingLeft = section.level === 3 ? '20px' : '0';
                label.onclick = () => {{
                    document.getElementById(section.id).scrollIntoView({{ behavior: 'smooth', block: 'start' }});
                }};

                item.appendChild(checkbox);
                item.appendChild(label);
                container.appendChild(item);
            }});

            updateProgressDisplay();
        }}

        // Run on page load
        document.addEventListener('DOMContentLoaded', initProgressTracker);
    </script>
</body>
</html>
"""

def convert_md_to_html(md_file, output_dir):
    """Convert a single markdown file to beautiful HTML with progress tracking"""
    try:
        # Read markdown
        with open(md_file, 'r', encoding='utf-8') as f:
            md_content = f.read()

        # Convert markdown to HTML
        md = markdown.Markdown(extensions=EXTENSIONS)
        html_content = md.convert(md_content)

        # Generate file ID for localStorage (clean filename)
        file_id = re.sub(r'[^a-z0-9]', '_', md_file.stem.lower())

        # Apply template
        final_html = HTML_TEMPLATE.format(
            title=md_file.stem,
            filename=md_file.name,
            timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            content=html_content,
            file_id=file_id
        )

        # Write output
        output_file = output_dir / f"{md_file.stem}.html"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(final_html)

        return True, output_file.name

    except Exception as e:
        return False, str(e)

def main():
    # Paths
    course_dir = Path(r'C:\Users\kasekar\GH\Course')
    md_dir = course_dir / 'dev'
    html_dir = course_dir / 'src'

    # Ensure output directory exists
    html_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("Markdown → HTML with PROGRESS TRACKING")
    print("=" * 60)
    print()

    # Get all markdown files
    md_files = sorted(md_dir.glob('*.md'))
    total = len(md_files)

    if total == 0:
        print("No markdown files found!")
        return

    print(f"Found {total} markdown files to convert\n")

    success_count = 0
    failed = []

    # Convert each file
    for i, md_file in enumerate(md_files, 1):
        print(f"[{i}/{total}] {md_file.name}...", end=' ')

        ok, result = convert_md_to_html(md_file, html_dir)

        if ok:
            print(f"✓ → {result}")
            success_count += 1
        else:
            print(f"✗ FAILED: {result}")
            failed.append((md_file.name, result))

    print()
    print("=" * 60)
    if success_count == total:
        print(f"✓ Success: {success_count}/{total}")
        print("=" * 60)
        print()
        print("NEW FEATURES:")
        print("  ✓ Progress checkboxes for each section")
        print("  ✓ Auto-saves to browser localStorage")
        print("  ✓ Progress percentage tracker")
        print("  ✓ Click section to scroll to it")
        print("  ✓ Reset button to clear progress")
        print()
    else:
        print(f"⚠ Completed: {success_count}/{total}")
        print("=" * 60)
        if failed:
            print("\nFailed files:")
            for fname, error in failed:
                print(f"  ✗ {fname}: {error}")
        print()

if __name__ == '__main__':
    main()
