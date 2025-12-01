# Useful SVG Export Commands

## Single Token
```bash
./contracts/scripts/export_svg.sh 123456 1 1 1 exports/path_123456.svg
```

## Batch (tokens 1-10)
```bash
mkdir -p exports &&
for id in 1 2 3 4 5 6 7 8 9 10; do
  ./contracts/scripts/export_svg.sh "$id" 1 1 1
done &&
node contracts/scripts/build_gallery.js exports --title "PATH Token Drafts"
```

> Run the command from the repository root. When no output path is provided,
> SVGs are written to `./exports/path_<token_id>.svg`, and the gallery is
> regenerated automatically afterward.

## Build a Browser-Accurate Gallery
Finder thumbnails ignore SVG filters and blend modes, so use the gallery utility
to review multiple outputs exactly as they look in Safari/Chrome:
```bash
node contracts/scripts/build_gallery.js exports --title "PATH Token Drafts"
open exports/gallery.html  # macOS; otherwise open the file manually
```

Copy and run the snippets exactly as shown above.
