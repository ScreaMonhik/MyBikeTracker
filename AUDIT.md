# Аудит MyBikeTracker

Дата: 13 сентября 2026  
Источник: ревью репозитория (не TestFlight и не App Store Connect)

Локальный велосипедный трекер: iPhone 17.6+, Watch 10.6+, виджеты и Live Activity. ~69 Swift-файлов, ~25k строк, SwiftData, без облака.

| | |
| --- | --- |
| Итог | **5.5 / 10** |
| Критичные риски | 3 |
| Высокий приоритет | 8 |
| Автотестов | 0 |

**Вердикт: продукт сильный, релиз в Store — нет.** Ядро поездки, карта, история и бренд уже на уровне хорошего инди-трекера. Релиз блокируют потеря данных, Always-GPS с первого запуска, дыры в приватности и виджет, который не ставится на заявленный iOS 17.6.

Держать как личный трекер — уже можно. Отдавать незнакомым людям или в ревью Apple — после P0: данные не должны исчезать, GPS не должен работать «на всякий случай», виджет должен ставиться на тот же iOS, что и приложение.

---

## Оценки по осям

Шкала 0–10. Порог 7 — минимальный уровень «можно показывать людям вне TestFlight».

| Ось | Оценка |
| --- | ---: |
| Дизайн / UX | 8.0 |
| Продукт | 7.5 |
| Локализация | 6.5 |
| Архитектура | 6.5 |
| Доступность | 6.0 |
| Watch / виджет | 5.0 |
| Батарея / perf | 4.5 |
| Приватность | 4.0 |
| App Store | 4.0 |
| Надёжность | 3.5 |
| Аналитика | 2.0 |
| Тесты | 1.0 |

---

## Что уже сильно

Это не каркас. Есть полный цикл поездки, карта всех треков, история с недельной целью, гараж и цепь, BLE-датчики, HealthKit write, Watch, виджеты, Dynamic Island, журнал дня и JSON export/import. Бренд Trail Dawn последователен: токены, Liquid Glass с fallback, Reduce Motion, hapтики, пустые состояния.

- Сохранение поездки до Mapbox matching
- Разрыв GPS без «телепорта» прямой линией
- Heatmap скорости
- Локали en / ru / uk в основном приложении
- `Secrets.xcconfig` в gitignore
- Подтверждение стопа на iPhone
- Icon: layers + dark + tint
- Live Activity с прошлого краша гасится при старте
- PhotosPicker без полного доступа к галерее
- DEBUG-симулятор дороги спрятан за `#if DEBUG`

---

## Критичные риски

Три вещи, из-за которых пользователь теряет поездку или Apple режет ревью.

### 1. Store wipe при старте

Если SwiftData не открывается — в том числе после смены схемы — приложение удаляет `.store` / `.shm` / `.wal` и создаёт пустую базу. Все поездки, велосипеды и журнал пропадают без бэкапа. Второй провал — `fatalError`.

`MyBikeTrackerApp.swift`, строки 22–36

### 2. Живой трек только в RAM

Точки, время и паузы живут в `LocationService` / `MapViewModel`. Нет `scenePhase`-снимка и восстановления. Jetsam, краш или убийство процессом — поездка исчезает. Live Activity при этом ещё и принудительно гасится при следующем запуске.

`LocationService.swift` · `MapViewModel.swift` · `LiveActivityService.swift:20–23`

### 3. Always + GPS с первого кадра

`LocationService` в `init` сразу зовёт `requestAlwaysAuthorization` и `startUpdatingLocation`, `allowsBackgroundLocationUpdates = true` даже без записи. Bluetooth `CBCentralManager` тоже создаётся при старте приложения. Guideline 5.1.4 и расход батареи на домашнем экране.

`LocationService.swift:31–40` · `BluetoothSensorService.swift:48–50`

---

## Все находки

- **Crit** — потеря данных или почти гарантированный отказ ревью
- **High** — ломает обещание продукта или блокирует сабмит
- **Med** — дыра в сценарии
- **Low** — шлифовка до 1.1

| Ур. | Ось | Суть | Где |
| --- | --- | --- | --- |
| Crit | Данные | Удаление SwiftData store при любой ошибке открытия | `MyBikeTrackerApp.swift:22–36` |
| Crit | Трекинг | Нет checkpoint живой поездки на диск | `MapViewModel` / `LocationService` |
| Crit | Приватность | Always + фон + continuous GPS до старта поездки | `LocationService.swift:31–40` |
| High | Виджет | `IPHONEOS_DEPLOYMENT_TARGET` виджета 26.2 при приложении 17.6 | `project.pbxproj:586, 618` |
| High | Watch | Stop на часах вызывает `stopTracking()` без экрана подтверждения | `RideSessionBridge.swift:57–58` |
| High | Store | Нет `PrivacyInfo.xcprivacy` (UserDefaults, file timestamp, сеть) | репозиторий |
| High | Health | `NSHealthShareUsageDescription` обещает чтение, код пишет `read: []` | `pbxproj:507` · `HealthKitService.swift:31` |
| High | Review | Проектный `NSLocationWhenInUse`: «А ну давай сюда свою геопозицию» | `pbxproj:419, 479` |
| High | Надёжность | `try? modelContext.save()` глотает ошибку записи | `RidesViewModel.swift:307–309` |
| High | Качество | Нет XCTest / UI-тестов на дистанцию, гэпы, import, persist | нет test target |
| High | Виджет | В бандл попал шаблон Control Widget «Start Timer» — всегда On, к поездке не привязан | `BikeTrackerWidgetControl.swift` / `WidgetBundle.swift:16` |
| Med | UX | `authorizationStatus` нигде не показан — нет экрана «разрешите GPS» | `Views/*` |
| Med | Продукт | Нет Discard и порога минимальной поездки — карманный старт пишется | `EndRideConfirmationView` / `persistRide` |
| Med | Сенсоры | Пульс и каденс не пишутся в Ride и не уходят в HealthKit | `BluetoothSensorService` / `HealthKitService` |
| Med | Backup | Export без велосипедов и журнала; import не крутит одометр | `RideExportDTO` / `importRides` |
| Med | Карта | Домашняя карта рисует heatmap всех поездок сразу | `HomeMapView` / `UKitMapView:107–124` |
| Med | Качество трека | Mapbox matching режет сегмент до 100 точек | `MapboxRouteService.swift:14, 53–54` |
| Med | Навигация | Long-press строит маршрут как automobile, не cycling | `MapViewModel.swift:328` |
| Med | Приватность | Export отдаёт полный GPS-трек без предупреждения; нет ссылки на privacy policy | `RideImportExportSection` / Settings |
| Med | A11y | Шрифты Brand — фиксированный size, нет Dynamic Type | `Brand.swift:45–58` |
| Low | Watch | Часы и виджет: только EN, км/ч, без единиц из Settings | `WatchRideView` / `BikeTrackerWidget` |
| Low | Health | Калории = 25 ккал/км; `HKWorkout` API deprecated с iOS 17 | `HealthKitService.swift:55–63, 82–86` |
| Low | ASO | Нет display name, preview, RequestReview, промо-текста | `pbxproj` / Views |
| Low | Имя | Bundle `dimsun.*`, App Group `group.com.sunko.*` — путаница в аккаунтах | entitlements / `AppGroupConfig.swift` |
| Low | Архитектура | `RideRemoteProtocol.swift` скопирован в iPhone и Watch — риск разъехаться | `Models/` vs `BikeTrackerWatch/` |

Не баг (только имя константы): `yearlyDistanceValue` для миль умножает км на `0.621371` — численно верный перевод км → мили.

---

## Архитектура (кратко)

Три таргета, без SPM-зависимостей, без облака, без аналитики и монетизации.

| Таргет | Bundle ID | Роль | Min OS |
| --- | --- | --- | --- |
| MyBikeTracker | `dimsun.MyBikeTracker` | iPhone / iPad | iOS 17.6 |
| BikeTrackerWidgetExtension | `dimsun.MyBikeTracker.BikeTrackerWidget` | Виджеты + Live Activity | iOS 26.2 |
| BikeTrackerWatch | `dimsun.MyBikeTracker.watchkitapp` | Пульт поездки | watchOS 10.6 |

| Слой | Технология | Что хранится |
| --- | --- | --- |
| Поездки, велосипеды, журнал | SwiftData | `Ride`, `Bike`, `DayJournal` |
| Настройки | UserDefaults / `@AppStorage` | единицы, автопауза, байк, цвета, BLE UUID |
| Виджет | App Group UserDefaults | `group.com.sunko.mybiketracker` |
| Фото журнала | Application Support/DayPhotos | JPEG |
| Export | JSON | только поездки (`RideExportDTO`) |

Composition root: `MyBikeTrackerApp` → `LocationService`, `RidesViewModel`, `HealthKitService`, `LiveActivityService`, `MapViewModel`. BLE и Watch-мост живут внутри `MapViewModel`.

Внешние вызовы: Mapbox Map Matching (REST, опционально), MapKit Directions, HealthKit write, WatchConnectivity. Firebase / PostHog / RevenueCat / Sentry — нет.

---

## Готовность к Store

| Чек | Статус |
| --- | --- |
| Usage descriptions на таргете приложения | Есть, EN |
| Icon: layered + dark + tinted | Есть |
| Локали UI: en / ru / uk | Есть; Watch / виджет — нет |
| Privacy Manifest | Нет |
| Честные Health / Location strings | Расхождение |
| Виджет на iOS 17.6+ | Нет, target 26.2 |
| Control Widget | Шаблон Timer, не поездка |
| `ITSAppUsesNonExemptEncryption` | Не задан |
| `CFBundleDisplayName` приложения | Не задан |
| Рейтинг / RequestReview | Нет |
| Privacy policy URL | Нет |

**ASO.** Имя таргета MyBikeTracker не использует 30 символов и не несёт поисковый интент. Виджет в галерее называется BikeTrackerWidget. Скриншотов, preview и keyword field в репозитории нет. Сначала починить данные и разрешения: иначе трафик упрётся в отзывы «пропала поездка». ASO имеет смысл после P0.

Для App Privacy questionnaire заранее: precise location, HealthKit write, Mapbox как third-party (координаты по HTTPS).

---

## Очерёдность работ

P0 — до любого TestFlight внешним людям. P1 — до App Store. P2 — 1.1.

### P0

- [ ] Не удалять SwiftData store. Миграции, бэкап, понятная ошибка вместо wipe + `fatalError`
- [ ] Писать живую поездку в App Group каждые N точек и восстанавливать после краша
- [ ] When In Use при первом запуске; Always и background updates только во время записи; стоп GPS на карте в покое
- [ ] `PrivacyInfo.xcprivacy`, честные Health/Location strings, убрать проектный «А ну давай сюда…»
- [ ] Выровнять deployment виджета с приложением (17.6) или явно поднять минимум всего бандла
- [ ] Stop с часов → тот же confirm, что на iPhone (или явный Discard)

### P1

- [ ] XCTest: дистанция, гэпы, persist, import UUID, checkpoint restore
- [ ] Discard + минимальная дистанция/время; экран «локация запрещена»
- [ ] Пульс в HealthKit; каденс/HR в модели поездки; не глотать `save()`
- [ ] Убрать или привязать Control Widget к поездке; long-press маршрут — cycling; предупреждение перед GPS-export

### P2

- [ ] Display name, ASO, RequestReview после сохранённой поездки
- [ ] Локаль часов и виджета, единицы из Settings
- [ ] iCloud / полный backup (байки + журнал)
- [ ] Dynamic Type, общий `RideRemoteProtocol`, crash reporting

---

## Следующий проход

Закрыть три Crit и прогнать одну живую поездку с фоном, крашем и Stop с часов.
