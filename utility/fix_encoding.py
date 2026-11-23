#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fix encoding issues and remove .md extensions from titles in all HTML and MD files
"""

import os
import re
from pathlib import Path

# Character replacements (garbled -> correct)
CHAR_REPLACEMENTS = {
    'ðŸ"š': '📚',
    'ðŸ"': '🔍',
    'ðŸš€': '🚀',
    'ðŸ"Š': '📊',
    'â­': '⭐',
    'ðŸ"Œ': '📌',
    'ðŸŽ¯': '🎯',
    'ðŸ"‹': '📋',
    'ðŸ—ï¸': '🗺️',
    'ðŸ"–': '📖',
    'ðŸ"„': '📄',
    'âœï¸': '✍️',
    'ðŸŽ¤': '🎤',
    'ðŸ"˜': '📘',
    'ðŸ"—': '📗',
    'ðŸ'»': '💻',
    'ðŸ"…': '📅',
    'ðŸ"§': '🔧',
    'â˜ï¸': '☁️',
    'ðŸ"Œ': '🔌',
    'ðŸ'³': '💳',
    'âš¡': '⚡',
    'ðŸ"¨': '📨',
    'â˜¸ï¸': '☸️',
    'ðŸ"„': '🔄',
    'ðŸ¤–': '🤖',
    'ðŸ': '🐍',
    'âš›ï¸': '⚛️',
    'â‚¹': '₹',
    'â†'': '↑',
    'â†'': '→',
    'Ã—': '×',
}

def fix_file(file_path):
    """Fix encoding issues and titles in a single file"""
    try:
        # Read file
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        original = content

        # Fix character encoding
        for garbled, correct in CHAR_REPLACEMENTS.items():
            content = content.replace(garbled, correct)

        # For HTML files: remove .md from titles (but not from href links)
        if file_path.suffix == '.html':
            # Remove .md from <h1>, <h2>, <h3> tags
            content = re.sub(r'(<h[123]>)([^<]*?)\.md(<)', r'\1\2\3', content)

            # Remove .md from <title> tags
            content = re.sub(r'(<title>)([^<]*?)\.md(<)', r'\1\2\3', content)

            # Remove .md from visible text (but not in href="...")
            lines = content.split('\n')
            new_lines = []
            for line in lines:
                if 'href=' not in line:
                    # Safe to remove .md from display text
                    line = re.sub(r'>([^<]*?)\.md<', r'>\1<', line)
                new_lines.append(line)
            content = '\n'.join(new_lines)

        # Save if changed
        if content != original:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True

        return False

    except Exception as e:
        print(f"ERROR processing {file_path}: {e}")
        return False


def main():
    course_path = Path(r'C:\Users\kasekar\GH\Course')

    print("="*50)
    print("Fixing Encoding Issues & Titles")
    print("="*50)
    print()

    # Find all HTML and MD files
    html_files = list(course_path.rglob('*.html'))
    md_files = list(course_path.rglob('*.md'))
    all_files = html_files + md_files

    total = len(all_files)
    fixed = 0

    print(f"Found {total} files to process\n")

    for i, file_path in enumerate(all_files, 1):
        relative = file_path.relative_to(course_path)
        print(f"[{i}/{total}] Processing: {relative}", end='... ')

        if fix_file(file_path):
            print("✓ FIXED")
            fixed += 1
        else:
            print("- OK")

    print()
    print("="*50)
    print(f"Complete! Fixed {fixed}/{total} files")
    print("="*50)


if __name__ == '__main__':
    main()
