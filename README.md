# MigraineTracker

Нативний щоденник мігрені для iOS на SwiftUI та SwiftData.

- Календар місяця та року.
- Відмітки мігрені з аурою та без аури.
- 16 стандартних тригерів і власні тригери з емоджі.
- Коментарі до дня до 200 символів.
- Українська, англійська та російська мови.
- Локальне зберігання без акаунта та синхронізації.

## Запуск

Відкрий `MigraineTracker.xcodeproj` у Xcode, обери схему `MigraineTracker` і симулятор iPhone, натисни Run (⌘R). Для фізичного iPhone обери свою Team у Signing & Capabilities.

## Документація

- [Специфікація](docs/spec.md)
- [План](docs/plan.md)
- [Завдання та перевірки](docs/tasks.md)
- [Дизайн](docs/design.md)

## Перевірки моделей

На Mac із встановленим Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc MigraineTracker/Models/*.swift Checks/DayEntryStoreChecks.swift -o /tmp/MigraineTracker-store-checks
/tmp/MigraineTracker-store-checks
```
