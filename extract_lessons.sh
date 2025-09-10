#!/bin/bash

# Extract lesson-specific word lists from UFLI PDFs
echo "Extracting lesson-specific word lists from UFLI PDFs..."

# Create directories for organized output
mkdir -p lesson_lists/kindergarten
mkdir -p lesson_lists/first_grade  
mkdir -p lesson_lists/second_grade

# Function to extract lesson content
extract_lesson_words() {
    local pdf_file="$1"
    local output_dir="$2"
    local grade_name="$3"
    
    echo "Processing $grade_name lessons from $pdf_file..."
    
    # Extract full text
    local full_text=$(pdftotext "$pdf_file" -)
    
    # Get all lesson headers
    local lesson_headers=$(echo "$full_text" | grep -i "^Lesson [0-9]" | sort -u)
    
    echo "Found lesson headers:"
    echo "$lesson_headers"
    
    # Process each lesson
    while IFS= read -r lesson_header; do
        if [[ -n "$lesson_header" ]]; then
            # Clean up lesson name for filename
            local lesson_name=$(echo "$lesson_header" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g')
            local output_file="$output_dir/${lesson_name}.txt"
            
            echo "Extracting words for: $lesson_header"
            
            # Extract content between this lesson and next lesson
            # This is a simplified approach - we'll extract words that appear near this lesson
            local lesson_content=$(echo "$full_text" | awk -v lesson="$lesson_header" '
                BEGIN { found = 0; collect = 0 }
                $0 ~ lesson { found = 1; collect = 1; next }
                /^Lesson [0-9]/ && found && collect { collect = 0 }
                collect { print }
                END { }
            ')
            
            # Extract words from lesson content
            if [[ -n "$lesson_content" ]]; then
                echo "$lesson_content" | \
                    grep -E '^[a-z]{2,12}$' | \
                    sort -u > "$output_file"
                
                local word_count=$(wc -l < "$output_file")
                echo "  → $word_count words extracted to $output_file"
            else
                echo "  → No content found for $lesson_header"
            fi
        fi
    done <<< "$lesson_headers"
}

# Extract lessons from each PDF
extract_lesson_words "assets/images/Foundations-Roll-and-Read-K.pdf" "lesson_lists/kindergarten" "Kindergarten"
extract_lesson_words "assets/images/Foundations-Roll-and-Read-First.pdf" "lesson_lists/first_grade" "First Grade"  
extract_lesson_words "assets/images/Foundations-Roll-and-Read-Second.pdf" "lesson_lists/second_grade" "Second Grade"

echo ""
echo "Lesson extraction complete!"
echo ""
echo "Kindergarten lessons: $(ls lesson_lists/kindergarten/*.txt 2>/dev/null | wc -l)"
echo "First Grade lessons: $(ls lesson_lists/first_grade/*.txt 2>/dev/null | wc -l)"
echo "Second Grade lessons: $(ls lesson_lists/second_grade/*.txt 2>/dev/null | wc -l)"