# LIVP to JPG Batch Converter for macOS

A script to convert Apple Live Photos (.livp) files to standard JPG images, addressing compatibility issues with macOS Sequoia and providing a convenient way to batch convert files for upload to photo-sharing sites.

## Installation

1. Ensure you have the following tools installed:
   - `unzip`
   - Either `sips` (built-in macOS tool) or `ImageMagick`

2. Install required tools using Homebrew:
   ```bash
   brew install unzip imagemagick
   ```

## Usage

Run the script in your terminal:

```bash
./convert_livp.sh [input_directory] [output_directory]
```

### Examples

1. Convert from current directory:
   ```bash
   ./convert_livp.sh
   ```

2. Convert from specific directory:
   ```bash
   ./convert_livp.sh ~/Pictures/LivePhotos
   ```

3. Convert from specific input directory to a specific output directory:
   ```bash
   ./convert_livp.sh ~/Pictures/LivePhotos ~/Pictures/Converted_JPGs
   ```

## Features

- Converts `.livp` files to JPG
- Handles multiple file formats (HEIC, JPG, etc.)
- Supports both `sips` (native macOS) and ImageMagick for image conversion
- Automatic retries on failed conversions
- Error handling and cleanup

## Contributing

Contributions are welcome! If you find an issue or have a suggestion, please open an issue or submit a pull request.

## License

MIT License