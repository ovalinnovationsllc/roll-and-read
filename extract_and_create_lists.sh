#!/bin/bash

# Extract text from PDFs and clean up to get word lists
echo "Extracting words from UFLI PDFs..."

# Kindergarten words
echo "Processing Kindergarten PDF..."
pdftotext "assets/images/Foundations-Roll-and-Read-K.pdf" - | \
  grep -E '^[a-z]{2,8}$' | \
  sort -u > kindergarten_words.txt

# First Grade words  
echo "Processing First Grade PDF..."
pdftotext "assets/images/Foundations-Roll-and-Read-First.pdf" - | \
  grep -E '^[a-z]{2,10}$' | \
  sort -u > first_grade_words.txt

# Second Grade words
echo "Processing Second Grade PDF..."
pdftotext "assets/images/Foundations-Roll-and-Read-Second.pdf" - | \
  grep -E '^[a-z]{2,12}$' | \
  sort -u > second_grade_words.txt

echo "Word extraction complete!"
echo ""
echo "Kindergarten words: $(wc -l < kindergarten_words.txt)"
echo "First Grade words: $(wc -l < first_grade_words.txt)"
echo "Second Grade words: $(wc -l < second_grade_words.txt)"