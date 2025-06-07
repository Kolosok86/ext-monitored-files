#!/bin/bash

# === Конфигурация ===
WORKDIR="/home/vladislav/ext-monitored-files"  # путь к проекту
ARCHIVE_URL="https://download.steaminventoryhelper.com/chrome-extension.zip"
ARCHIVE_FILE="/tmp/chrome-extension.zip"
TMP_DIR="/tmp/chrome-extension"
TARGET_FILE="assets/data/cached-key-items.json"
OLD_HASH_FILE="/tmp/old_cached_key_hash.txt"

# === Переход в рабочую директорию ===
cd "$WORKDIR" || exit 1

# === Скачивание архива с кастомными заголовками ===
wget \
  --header="User-Agent: Mozilla/5.0 (X11; Linux x86_64)" \
  --header="Referer: https://steamcommunity.com/" \
  --header="Accept: */*" \
  "$ARCHIVE_URL" -O "$ARCHIVE_FILE"

if [ $? -ne 0 ]; then
  echo "❌ Ошибка при загрузке архива"
  exit 1
fi

# === Распаковка ===
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
unzip -qq "$ARCHIVE_FILE" -d "$TMP_DIR"

# === Проверка наличия файла ===
EXTRACTED_FILE="$TMP_DIR/$TARGET_FILE"
if [ ! -f "$EXTRACTED_FILE" ]; then
  echo "❌ Файл $TARGET_FILE не найден в архиве"
  exit 1
fi

# === Сравнение хешей ===
NEW_HASH=$(sha256sum "$EXTRACTED_FILE" | cut -d ' ' -f1)
OLD_HASH=$(cat "$OLD_HASH_FILE" 2>/dev/null)

if [ "$NEW_HASH" != "$OLD_HASH" ]; then
  echo "✅ Обнаружены изменения, обновляем файл..."

  # Копируем файл
  mkdir -p "$(dirname "$WORKDIR/$TARGET_FILE")"
  cp "$EXTRACTED_FILE" "$WORKDIR/$TARGET_FILE"

  # Обновляем хеш
  echo "$NEW_HASH" > "$OLD_HASH_FILE"

  # Коммит и пуш
  git add "$TARGET_FILE"
  git commit -m "Update cached-key-items.json ($(date +'%Y-%m-%d %H:%M:%S'))"
  git push
else
  echo "ℹ️  Изменений не обнаружено."
fi
