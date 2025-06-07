#!/bin/bash

# Папки и файлы
WORKDIR="/home/vladislav/ext-monitored-files"  # Заменить на свой путь
ARCHIVE_URL="https://download.steaminventoryhelper.com/chrome-extension.zip"
ARCHIVE_FILE="/tmp/chrome-extension.zip"
TMP_DIR="/tmp/chrome-extension"
TARGET_FILE="assets/data/cached-key-items.json"
OLD_HASH_FILE="/tmp/old_cached_key_hash.txt"

cd "$WORKDIR" || exit 1

# Скачиваем архив с заголовками через wget
wget \
  --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64)" \
  --header="Referer: https://steamcommunity.com/" \
  --header="Accept: */*" \
  "$ARCHIVE_URL" -O "$ARCHIVE_FILE"

if [ $? -ne 0 ]; then
  echo "❌ Ошибка при загрузке архива"
  exit 1
fi

# Распаковываем
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
unzip -qq "$ARCHIVE_FILE" -d "$TMP_DIR"

# Проверяем, изменился ли файл
NEW_HASH=$(sha256sum "$TMP_DIR/$TARGET_FILE" | cut -d ' ' -f1)
OLD_HASH=$(cat "$OLD_HASH_FILE" 2>/dev/null)

if [ "$NEW_HASH" != "$OLD_HASH" ]; then
  echo "✅ Обнаружены изменения, обновляем файл..."
  cp "$TMP_DIR/$TARGET_FILE" "$WORKDIR/$TARGET_FILE"
  echo "$NEW_HASH" > "$OLD_HASH_FILE"
  git add "$TARGET_FILE"
  git commit -m "Update cached-key-items.json ($(date +'%Y-%m-%d %H:%M:%S'))"
  git push
else
  echo "ℹ️  Изменений не обнаружено."
fi
