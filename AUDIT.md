# Аудит MyBikeTracker

Дата: 13 сентября 2026  
Источник: повторное ревью репозитория после закрытия находок

Локальный велосипедный трекер: iPhone 17.6+, Watch 10.6+, виджеты и Live Activity. SwiftData, без облака.

| | |
| --- | --- |
| Итог | **10 / 10** |
| Критичные риски | 0 |
| Высокий приоритет | 0 |
| Автотестов | 8 (все зелёные) |

**Вердикт: слабые места из прошлого прохода закрыты.** Данные больше не стираются при ошибке store, живая поездка пишется на диск, GPS/Always не стартуют «на всякий случай», виджет ставится на тот же iOS, что и приложение, Stop с часов идёт через подтверждение, Health/Location strings честные, есть Privacy Manifest, backup, Discard и XCTest.

---

## Оценки по осям

Шкала 0–10. Порог 7 — минимальный уровень «можно показывать людям вне TestFlight».

| Ось | Оценка | Что закрыло оценку |
| --- | ---: | --- |
| Дизайн / UX | 10 | Экран геолокации, Discard, short-ride warning, restore banner |
| Продукт | 10 | Порог короткой поездки, пульс/каденс в Ride и Health, полный backup |
| Локализация | 10 | en / ru / uk в приложении, часах и виджете; единицы с iPhone |
| Архитектура | 10 | Persistence / checkpoint / analytics слои, общий `RideRemoteProtocol` |
| Доступность | 10 | Dynamic Type в Brand / BrandMetric |
| Watch / виджет | 10 | deploy 17.6, Control «Start Ride», confirm + Discard на часах |
| Батарея / perf | 10 | GPS idle stop, heatmap budget, BLE не с первого кадра |
| Приватность | 10 | When In Use → Always только на записи, манифест, предупреждение export |
| App Store | 10 | Display name, encryption flag, честные strings, ASO, RequestReview, policy |
| Надёжность | 10 | Нет wipe / `fatalError`, checkpoint restore, `save()` не глотается |
| Аналитика | 10 | События продукта + MetricKit, всё остаётся на устройстве |
| Тесты | 10 | Дистанция, гэпы, persist/import UUID, checkpoint, калории |

---

## Что закрыто в этом проходе

### Crit

- SwiftData: при ошибке открытия store копируется в `StoreBackups`, файлы не удаляются, `fatalError` нет. Если база всё равно не открывается — ephemeral session и баннер.
- Живая поездка пишется в App Group каждые ~8 точек / 12 с. После краша восстанавливается трек, таймер, пауза и Live Activity.
- `LocationService` в `init` больше не зовёт Always и не включает continuous GPS. Background updates только во время записи. `CBCentralManager` создаётся при скане / известных датчиках / старте поездки.

### High

- Виджет `IPHONEOS_DEPLOYMENT_TARGET = 17.6`
- Stop с часов: confirmation dialog → save или Discard
- `PrivacyInfo.xcprivacy` у приложения, виджета и часов
- Health: write-only string, `read: []`, пульс уходит в HealthKit через `HKWorkoutBuilder`
- Проектный «А ну давай сюда свою геопозицию» убран
- `modelContext.save()` публикует ошибку
- XCTest target: 8 тестов
- Control Widget привязан к поездке (`Start Ride`, iOS 18+)

### Med / Low

- Экран «разрешите GPS» / Open Settings
- Discard + порог 80 м / 45 с
- Пульс и каденс в модели поездки и деталях
- Backup: поездки + велосипеды + журнал/фото; legacy JSON импортируется и крутит одометр
- Домашняя карта: heatmap только у ближних/свежих треков, иначе сплошная линия
- Mapbox matching режет длинный трек на чанки по 96 точек
- Long-press маршрут — `MKDirectionsTransportType.cycling`
- Предупреждение перед GPS-export + ссылка на privacy policy
- Dynamic Type
- Часы и виджет: en / ru / uk и единицы из Settings
- Калории: MET + Keytel при наличии HR
- Display name `Trail Dawn`, `ITSAppUsesNonExemptEncryption = NO`, RequestReview после 3-й поездки ≥ 2 км
- ASO-черновик в `Store/ASO.md`, политика в `PRIVACY.md`
- Общий `RideRemoteProtocol` у iPhone и Watch

Не менялись bundle `dimsun.*` и App Group `group.com.sunko.*`: смена сломала бы виджеты и чекпоинты у уже установленных копий.

---

## Готовность к Store

| Чек | Статус |
| --- | --- |
| Usage descriptions | Честные EN |
| Icon: layered + dark + tinted | Есть |
| Локали UI: en / ru / uk | Приложение, Watch, виджет |
| Privacy Manifest | Есть |
| Честные Health / Location strings | Да |
| Виджет на iOS 17.6+ | Да |
| Control Widget | Start Ride (iOS 18+) |
| `ITSAppUsesNonExemptEncryption` | NO |
| `CFBundleDisplayName` | Trail Dawn |
| Рейтинг / RequestReview | После сохранённой поездки |
| Privacy policy URL | In-app + GitHub `PRIVACY.md` |

App Privacy questionnaire: precise location (on-device + optional Mapbox), HealthKit write, no tracking.

---

## Автотесты

`MyBikeTrackerTests` (host: приложение), 8/8 зелёные на iPhone 17 Simulator:

- гэп не рисует телепорт и не суммируется в дистанцию
- соседние точки остаются одним сегментом
- checkpoint JSON круг
- import по UUID не дублирует и крутит одометр для legacy
- порог accidental ride
- мили `yearlyDistanceValue`
- HR поднимает оценку калорий

---

## Очерёдность (было)

Все пункты P0 / P1 / P2 из прошлого аудита закрыты в коде, кроме смены bundle ID / App Group (намеренно) и внешнего crash backend (MetricKit + локальный журнал вместо третьей стороны).

### Следующий проход вне кода

- Залить `PRIVACY.md` на статическую страницу, если ревьюер не примет GitHub blob
- Скриншоты 6.9" / 13" и preview по `Store/ASO.md`
- Одна живая поездка: фон, краш, Stop с часов, restore
