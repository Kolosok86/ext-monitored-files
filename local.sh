#!/bin/bash
# monitor-steam-extension.sh - Локальный скрипт для мониторинга изменений

set -e

# Настройки
URL="https://download.steaminventoryhelper.com/chrome-extension.zip"
TARGET_FILE="assets/data/cached-key-items.json"
MONITOR_DIR="monitored-files"
TEMP_ZIP="chrome-extension.zip"

echo "=== Steam Inventory Helper Monitor ==="
echo "Starting at $(date)"

# Создаем директорию для мониторинга
mkdir -p "$MONITOR_DIR"

# Скачиваем архив
echo "Downloading $URL..."
if ! wget -q "$URL" -O "$TEMP_ZIP"; then
    echo "Error: Failed to download file"
    exit 1
fi

# Проверяем размер скачанного файла
if [ ! -s "$TEMP_ZIP" ]; then
    echo "Error: Downloaded file is empty"
    rm -f "$TEMP_ZIP"
    exit 1
fi

# Распаковываем архив
echo "Extracting archive..."
if ! unzip -q "$TEMP_ZIP"; then
    echo "Error: Failed to extract archive"
    rm -f "$TEMP_ZIP"
    exit 1
fi

# Проверяем существование целевого файла
if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: Target file $TARGET_FILE not found in archive"
    echo "Available files:"
    find . -name "*.json" -type f | head -10
    cleanup_and_exit 1
fi

# Функция очистки
cleanup_and_exit() {
    rm -f "$TEMP_ZIP"
    rm -rf assets/ manifest.json background.js content.js popup.* options.* icons/ _locales/ || true
    exit ${1:-0}
}

# Проверяем изменения
CHANGES_DETECTED=false
STORED_FILE="$MONITOR_DIR/cached-key-items.json"

if [ -f "$STORED_FILE" ]; then
    if cmp -s "$TARGET_FILE" "$STORED_FILE"; then
        echo "No changes detected in $TARGET_FILE"
        cleanup_and_exit 0
    else
        echo "Changes detected in $TARGET_FILE!"
        CHANGES_DETECTED=true
    fi
else
    echo "First run - saving initial version of $TARGET_FILE"
    CHANGES_DETECTED=true
fi

if [ "$CHANGES_DETECTED" = true ]; then
    # Копируем новую версию
    cp "$TARGET_FILE" "$STORED_FILE"
    
    # Сохраняем метаданные
    cat > "$MONITOR_DIR/last-update.txt" << EOF
Last updated: $(date -u)
Source: $URL
File size: $(stat -c%s "$TARGET_FILE" 2>/dev/null || stat -f%z "$TARGET_FILE" 2>/dev/null || echo "unknown") bytes
Checksum: $(sha256sum "$TARGET_FILE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$TARGET_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
EOF
    
    # Делаем git commit если мы в git репозитории
    if [ -d ".git" ]; then
        echo "Making git commit..."
        
        git add "$MONITOR_DIR/"
        
        COMMIT_MSG="Update cached-key-items.json - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        
        if git commit -m "$COMMIT_MSG"; then
            echo "Changes committed successfully"
            
            # Спрашиваем о push (только в интерактивном режиме)
            if [ -t 0 ]; then
                read -p "Push changes to remote? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git push
                    echo "Changes pushed to remote"
                fi
            else
                echo "Non-interactive mode - skipping push"
            fi
        else
            echo "No changes to commit (files already staged?)"
        fi
    else
        echo "Not a git repository - changes saved locally only"
    fi
    
    echo "File updated successfully!"
else
    echo "No changes detected"
fi

cleanup_and_exit 0
