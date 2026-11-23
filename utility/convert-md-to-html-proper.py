#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Proper Markdown to HTML converter using Python markdown library
Handles ALL markdown features: tables, code blocks, lists, etc.
"""

import markdown
from pathlib import Path
from datetime import datetime

# Markdown extensions for full feature support
EXTENSIONS = [
    'extra',          # Tables, fenced code blocks, footnotes
    'codehilite',     # Syntax highlighting
    'toc',            # Table of contents
    'nl2br',          # Newline to <br>
    'sane_lists',     # Better list handling
]

# HTML template with beautiful styling
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
            margin-bottom: 40px;
            font-size: 0.9em;
            color: #666;
            border-left: 4px solid #667eea;
        }}

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

        ul ul, ol ul, ul ol, ol ol {{
            margin-top: 10px;
            margin-bottom: 10px;
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

        /* Syntax highlighting styles */
        .codehilite {{
            background: #2d2d2d;
            border-radius: 8px;
            padding: 24px;
            margin: 25px 0;
            overflow-x: auto;
        }}

        .codehilite pre {{
            background: none;
            padding: 0;
            margin: 0;
            border: none;
            box-shadow: none;
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

            table {{
                font-size: 0.9em;
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

        <div class="content">
{content}
        </div>
    </div>
</body>
</html>
"""

def convert_md_to_html(md_file, output_dir):
    """Convert a single markdown file to beautiful HTML"""
    try:
        # Read markdown
        with open(md_file, 'r', encoding='utf-8') as f:
            md_content = f.read()

        # Convert to HTML using proper markdown parser
        md = markdown.Markdown(extensions=EXTENSIONS)
        html_content = md.convert(md_content)

        # Prepare template variables
        title = md_file.stem
        filename = md_file.name
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Apply template
        final_html = HTML_TEMPLATE.format(
            title=title,
            filename=filename,
            timestamp=timestamp,
            content=html_content
        )

        # Write HTML file
        output_file = output_dir / f"{title}.html"
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
    print("PROPER Markdown → HTML Conversion")
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

    # Summary
    print()
    print("=" * 60)
    print(f"✓ Success: {success_count}/{total}")
    if failed:
        print(f"✗ Failed: {len(failed)}")
        for name, error in failed:
            print(f"  - {name}: {error}")
    print("=" * 60)
    print()
    print("All HTML files now have:")
    print("  ✓ Proper tables")
    print("  ✓ Syntax-highlighted code blocks")
    print("  ✓ Beautiful formatting")
    print("  ✓ Responsive design")
    print("  ✓ Professional styling")


if __name__ == '__main__':
    main()
