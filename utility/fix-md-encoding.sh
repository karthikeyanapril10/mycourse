#!/bin/bash
# Fix encoding in all markdown files

echo "Fixing markdown files..."
count=0

for file in md/*.md; do
    # Create backup
    cp "$file" "$file.bak"
    
    # Fix garbled characters using sed
    sed -i 's/ðŸ"š/📚/g; s/ðŸš€/🚀/g; s/ðŸ"Š/📊/g; s/â‚¹/₹/g; s/â­/⭐/g; s/ðŸŽ¯/🎯/g; s/ðŸ"‹/📋/g; s/ðŸ"–/📖/g; s/ðŸ"„/📄/g; s/ðŸŽ¤/🎤/g; s/ðŸ'»/💻/g; s/ðŸ"…/📅/g; s/ðŸ"§/🔧/g; s/ðŸ"Œ/🔌/g; s/ðŸ'³/💳/g; s/ðŸ¤–/🤖/g; s/ðŸ/🐍/g; s/ðŸ—ï¸/🗺️/g; s/â˜ï¸/☁️/g; s/âš¡/⚡/g; s/ðŸ"¨/📨/g; s/ðŸ"/🔍/g; s/ðŸ"˜/📘/g; s/ðŸ"—/📗/g; s/â˜¸ï¸/☸️/g; s/ðŸ"„/🔄/g; s/âš›ï¸/⚛️/g; s/ðŸ"Œ/📌/g; s/âœï¸/✍️/g; s/Ã—/×/g' "$file"
    
    # Check if file changed
    if ! cmp -s "$file" "$file.bak"; then
        echo "✓ Fixed: $file"
        ((count++))
    fi
    
    # Remove backup
    rm "$file.bak"
done

echo ""
echo "Fixed $count markdown files"
