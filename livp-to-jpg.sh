#!/bin/bash
# LIVP to JPG Batch Converter for macOS
# This script converts Apple Live Photos (.livp) to standard JPG images
# Combines best practices from multiple approaches

# --- Configuration ---
MAX_RETRIES=3
DEBUG=false

# --- Color setup ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Cleanup function ---
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" &>/dev/null
    fi
}

# Register cleanup function to run on exit
trap cleanup EXIT

# --- Dependency checks ---
check_dependencies() {
    local missing=()
    
    if ! command -v unzip &>/dev/null; then
        missing+=("unzip")
    fi
    
    # Check for either sips (native macOS) or convert (ImageMagick)
    if ! command -v sips &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("ImageMagick")
        echo -e "${YELLOW}Note: Using native macOS sips would be preferred, but ImageMagick will work too${NC}"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}ERROR: Missing required tools: ${missing[*]}${NC}"
        echo "Install missing tools with: brew install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# --- LIVP conversion function ---
convert_livp() {
    local livp_file="$1"
    local output_dir="$2"
    local attempt=0
    local success=false
    
    # Get base filename without extension (case insensitive)
    local base_name=$(basename "$livp_file" .livp)
    base_name=$(basename "$base_name" .LIVP) # Handle uppercase extension
    
    # Define output path
    local output_file="$output_dir/$base_name.jpg"
    
    # Skip if output already exists
    if [[ -f "$output_file" ]]; then
        echo -e "${YELLOW}  ⚠️ Skipping (exists): $output_file${NC}"
        return 0
    fi
    
    # Multiple conversion attempts
    until [[ $attempt -ge $MAX_RETRIES || $success == true ]]; do
        ((attempt++))
        
        # Create secure temp directory
        TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'livpconv')
        if [[ ! -d "$TEMP_DIR" ]]; then
            echo -e "${YELLOW}  ⚠️ Failed to create temp directory (attempt $attempt)${NC}"
            continue
        fi
        
        # Copy LIVP file as ZIP to temp directory
        temp_zip="$TEMP_DIR/$base_name.zip"
        cp "$livp_file" "$temp_zip"
        
        # Extract the ZIP
        if ! unzip -q "$temp_zip" -d "$TEMP_DIR"; then
            echo -e "${YELLOW}  ⚠️ Extraction failed (attempt $attempt)${NC}"
            cleanup
            continue
        fi
        
        # Try to find the image file in multiple formats (HEIC, JPG, etc.)
        # First check for HEIC (preferred source format for Live Photos)
        local image_file=$(find "$TEMP_DIR" -type f \( -iname "*.heic" -o -iname "*.HEIC" \) -print -quit)
        
        # If no HEIC, look for JPG/JPEG
        if [[ -z "$image_file" ]]; then
            image_file=$(find "$TEMP_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.JPG" -o -iname "*.JPEG" \) -print -quit)
        fi
        
        # Last resort: find any image file by content type
        if [[ -z "$image_file" ]]; then
            image_file=$(find "$TEMP_DIR" -type f -exec file {} \; | grep -i "image data" | head -n 1 | cut -d':' -f1)
        fi
        
        # No image found, report failure
        if [[ -z "$image_file" ]]; then
            echo -e "${RED}  ❌ No image found in $livp_file${NC}"
            cleanup
            return 1
        fi
        
        # Convert the image - prefer sips (native macOS) if available
        if command -v sips &>/dev/null; then
            if sips -s format jpeg "$image_file" --out "$output_file" &>/dev/null; then
                success=true
                echo -e "${GREEN}  ✅ Converted with sips: $output_file${NC}"
            else
                echo -e "${YELLOW}  ⚠️ sips conversion failed (attempt $attempt)${NC}"
            fi
        # Fall back to ImageMagick if sips isn't available
        elif command -v convert &>/dev/null; then
            if convert "$image_file" -auto-orient -strip -quality 90 "$output_file"; then
                success=true
                echo -e "${GREEN}  ✅ Converted with ImageMagick: $output_file${NC}"
            else
                echo -e "${YELLOW}  ⚠️ ImageMagick conversion failed (attempt $attempt)${NC}"
            fi
        else
            echo -e "${RED}  ❌ No conversion tools available${NC}"
            cleanup
            return 1
        fi
        
        # Clean up temp files after each attempt
        cleanup
    done
    
    if [[ $success != true ]]; then
        echo -e "${RED}  ❌ Failed to convert $livp_file after $MAX_RETRIES attempts${NC}"
        return 1
    fi
    
    return 0
}

# --- Main execution function ---
main() {
    # Set up directories
    local input_dir="${1:-.}"  # Default to current directory if not specified
    local output_dir="${2:-Converted_JPGs}"  # Default output directory
    
    # Display usage if help requested
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        echo -e "${GREEN}LIVP to JPG Batch Converter for macOS${NC}"
        echo "Usage: $0 [input_directory] [output_directory]"
        echo "  - Default input: current directory"
        echo "  - Default output: ./Converted_JPGs"
        echo "Examples:"
        echo "  $0                          # Convert from current dir"
        echo "  $0 ~/Pictures/LivePhotos    # Convert from specific dir"
        echo "  $0 . ~/Desktop/Converted    # Specify output directory"
        exit 0
    fi
    
    echo -e "${GREEN}LIVP to JPG Batch Converter${NC}"
    
    # Check dependencies first
    if ! check_dependencies; then
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$output_dir" || {
        echo -e "${RED}ERROR: Cannot create output directory '$output_dir'${NC}"
        exit 1
    }
    
    # Make output directory absolute path
    output_dir=$(cd "$output_dir" && pwd)
    
    # Find all LIVP files
    local livp_count=0
    local success_count=0
    
    if [[ "$input_dir" == "." ]]; then
        # When in current directory, use shell globbing (more efficient)
        shopt -s nullglob
        livp_files=(*.livp *.LIVP)
        shopt -u nullglob
        livp_count=${#livp_files[@]}
        
        if [[ $livp_count -eq 0 ]]; then
            echo -e "${YELLOW}No LIVP files found in current directory.${NC}"
            exit 0
        fi
        
        echo -e "${GREEN}Found $livp_count LIVP file(s) to process${NC}"
        echo -e "Output will be saved to: ${YELLOW}$output_dir${NC}"
        echo ""
        
        # Process each file
        for livp_file in "${livp_files[@]}"; do
            echo -e "${YELLOW}Processing: $livp_file${NC}"
            if convert_livp "$livp_file" "$output_dir"; then
                ((success_count++))
            fi
        done
    else
        # For other directories, use find
        if [[ ! -d "$input_dir" ]]; then
            echo -e "${RED}ERROR: Input directory does not exist: $input_dir${NC}"
            exit 1
        fi
        
        # Count files first
        livp_count=$(find "$input_dir" -type f -iname "*.livp" | wc -l | tr -d ' ')
        
        if [[ $livp_count -eq 0 ]]; then
            echo -e "${YELLOW}No LIVP files found in $input_dir${NC}"
            exit 0
        fi
        
        echo -e "${GREEN}Found $livp_count LIVP file(s) to process in $input_dir${NC}"
        echo -e "Output will be saved to: ${YELLOW}$output_dir${NC}"
        echo ""
        
        # Process files using find with null separator for safe filename handling
        find "$input_dir" -type f -iname "*.livp" -print0 | while IFS= read -r -d $'\0' livp_file; do
            echo -e "${YELLOW}Processing: $livp_file${NC}"
            if convert_livp "$livp_file" "$output_dir"; then
                ((success_count++))
            fi
        done
    fi
    
    echo ""
    echo -e "${GREEN}Conversion complete: $success_count of $livp_count files converted${NC}"
    echo -e "Results saved in: ${YELLOW}$output_dir${NC}"
}

# Run main function with all arguments
main "$@"