#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [directory]"
    echo ""
    echo "Checks all .so and ELF executable files in the specified directory for missing shared library dependencies."
    echo "If no directory is provided, defaults to the current directory."
    echo ""
    echo "Example:"
    echo "  $0 ./open-source/lib"
}

is_elf_binary() {
    local file="$1"
    file "$file" | grep -q "ELF"
}

check_binary_file() {
    local file="$1"
    echo "------------------------------------------------------------"
    echo "📦 Checking: $file"

    if ! is_elf_binary "$file"; then
        echo "⚠️ Skipping non-ELF file: $file"
        return 0
    fi

    echo "🔍 Runpath:"
    readelf -d "$file" 2>/dev/null | grep -i "runpath" || echo "(none)"

    echo "🔍 Dependencies:"
    ldd "$file" || true

    if ldd "$file" | grep "not found"; then
        echo "❌ Missing dependencies detected in $file"
        return 1
    else
        echo "✅ All dependencies found in $file"
        return 0
    fi
}

main() {
    local DIR="${1:-.}"

    if [[ "$DIR" == "-h" || "$DIR" == "--help" ]]; then
        usage
        exit 0
    fi

    if [[ ! -d "$DIR" ]]; then
        echo "❌ Error: '$DIR' is not a directory."
        usage
        exit 1
    fi

    echo "🔍 Scanning directory: $DIR"
    local FAILED=0

    # Check .so* files
    while IFS= read -r -d '' file; do
        if ! check_binary_file "$file"; then
            FAILED=1
        fi
    done < <(find "$DIR" -type f -name "*.so*" -print0)

    # Check executable files
    while IFS= read -r -d '' file; do
        if ! check_binary_file "$file"; then
            FAILED=1
        fi
    done < <(find "$DIR" -type f -executable -print0)

    if [ "$FAILED" -ne 0 ]; then
        echo "❌ One or more binaries have missing dependencies."
        exit 1
    else
        echo "✅ All binaries passed dependency checks."
        exit 0
    fi
}

main "$@"
