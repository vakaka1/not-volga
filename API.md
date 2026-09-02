# Документация Merlin API (Транспорт Верхневолжья)

Официальный REST API мобильного приложения «Волга» (Транспорт Верхневолжья).

- **Базовый URL:** `https://api.merlin.tvercard.ru/api/client/v1/`
- **Формат данных:** `JSON` (кодировка UTF-8)
- **Заголовки по умолчанию:**
  ```http
  Accept: application/json
  Content-Type: application/json
  User-Agent: Dart/3.0 (dart:io)
  ```

---

## Обзор эндпоинтов

| Метод | Эндпоинт | Назначение |
|---|---|---|
| `GET` | [`/locations`](#1-получение-списка-городов-и-зон-get-locations) | Список регионов/городов обслуживания с гео-границами |
| `GET` | [`/tariffs`](#2-получение-тарифов-на-проезд-get-tariffs) | Актуальная стоимость проезда (наличный и безналичный расчёт) |
| `GET` | [`/routes`](#3-список-всех-маршрутов-get-routes) | Реестр всех маршрутов региона |
| `GET` | [`/routes/{route_id}`](#4-детали-маршрута-и-остановки-get-routesroute_id) | Маршрут с упорядоченным списком остановок |
| `GET` | [`/routes/{route_id}/path`](#5-геотрек-маршрута-для-карты-get-routesroute_idpath) | Точки полилинии (геотрек) маршрута для отрисовки на карте |
| `GET` | [`/stations`](#6-реестр-всех-остановок-get-stations) | Полный список остановок региона с координатами и адресами |
| `GET` | [`/stations/{station_id}`](#7-информация-об-остановке-get-stationsstation_id) | Данные конкретной остановки |
| `GET` | [`/stations/{station_id}/routes`](#8-маршруты-и-прогноз-прибытия-на-остановку-get-stationsstation_idroutes) | Маршруты через остановку и прогноз времени прибытия автобусов |
| `GET` | [`/vehicles`](#9-онлайн-позиции-транспорта-get-vehicles) | Телеметрия и координаты автобусов в реальном времени (в границах экрана/области) |
| `GET` | [`/beacons`](#10-список-bluetooth-маячков-get-beacons) | Реестр BLE iBeacon датчиков, установленных в транспорте |
| `GET` | [`/alerts`](#11-оповещения-и-предупреждения-get-alerts) | Системные уведомления и оперативные предупреждения |
| `GET` | [`/config`](#12-конфигурация-клиента-get-config) | Флаги возможностей и фиче-тогглы |
| `POST` | [`/tickets/buy`](#13-покупка-билета-post-ticketsbuy) | Запрос покупки билета через приложение |
| `GET` | [`/tickets`](#14-билеты-пассажира-get-tickets-get-ticketsactive-get-ticketshistory) | Запрос активных билетов и истории поездок |

---

## 1. Получение списка городов и зон (`GET /locations`)

Возвращает список всех обслуживаемых населенных пунктов Тверской области с координатами центров и ограничивающими прямоугольниками (bounding box).

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/locations`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[
  {
    "location_id": 1,
    "name": "Тверь",
    "region_id": 1,
    "order_index": 1,
    "timezone_name": "Europe/Moscow",
    "center_lat": 56.859625,
    "center_lng": 35.91186,
    "top_lat_bound": 56.93423,
    "bottom_lat_bound": 56.785747,
    "left_lng_bound": 35.737569,
    "right_lng_bound": 36.039364
  },
  {
    "location_id": 2,
    "name": "Ржев",
    "region_id": 1,
    "order_index": 2,
    "timezone_name": "Europe/Moscow",
    "center_lat": 56.263017,
    "center_lng": 34.334419,
    "top_lat_bound": 56.29368182922082,
    "bottom_lat_bound": 56.209298325134384,
    "left_lng_bound": 34.15597694472581,
    "right_lng_bound": 34.48556678847581
  }
]
```

### Описание полей
- `location_id` *(int)*: Уникальный идентификатор города/зоны (1 — Тверь, 2 — Ржев, 3 — Осташков, 4 — Пено, 5 — Кимры, 6 — Старица, 7 — Зубцов, 8 — Конаково).
- `name` *(string)*: Название города.
- `center_lat`, `center_lng` *(float)*: Координаты центра карты для города.
- `top_lat_bound`, `bottom_lat_bound`, `left_lng_bound`, `right_lng_bound` *(float)*: Географические границы (север, юг, запад, восток).
- `timezone_name` *(string)*: Часовой пояс локации.

---

## 2. Получение тарифов на проезд (`GET /tariffs`)

Возвращает стоимость разовой поездки для каждой локации.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/tariffs`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[
  {
    "tariff_id": 1,
    "location_id": 1,
    "cash_price": 5000,
    "cashless_price": 4000
  },
  {
    "tariff_id": 2,
    "location_id": 3,
    "cash_price": 2600,
    "cashless_price": 2500
  }
]
```

### Описание полей
- `tariff_id` *(int)*: Идентификатор тарифа.
- `location_id` *(int)*: Соответствующий ID локации (см. `/locations`).
- `cash_price` *(int)*: Стоимость проезда за наличный расчёт **в копейках** (например, `5000` = 50.00 ₽).
- `cashless_price` *(int)*: Стоимость проезда по банковской/транспортной карте **в копейках** (например, `4000` = 40.00 ₽).

---

## 3. Список всех маршрутов (`GET /routes`)

Возвращает полный каталог маршрутов транспорта региона.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/routes`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[
  {
    "route_id": 12423,
    "location_id": 1,
    "name": "33",
    "title": "Мигалово - Гипермаркет Леруа-Мерлен",
    "start_end_stations": "Мигалово - Гипермаркет Леруа-Мерлен",
    "end_station": "Гипермаркет Леруа-Мерлен",
    "vehicle_type_id": 2,
    "is_circular": false,
    "colour_hex": "",
    "comment": "",
    "agent_id": 0
  }
]
```

### Описание полей
- `route_id` *(int)*: Уникальный идентификатор маршрута (и его направления).
- `name` *(string)*: Номер маршрута (например, `"33"`, `"211с"`, `"1"`).
- `title` *(string)*: Название направления маршрута.
- `end_station` *(string)*: Название конечной остановки.
- `location_id` *(int)*: Идентификатор локации/города.
- `vehicle_type_id` *(int)*: Тип транспортного средства (`2` — автобус).
- `is_circular` *(bool)*: Признак кольцевого маршрута.
- `colour_hex` *(string)*: HEX-код цвета плашки маршрута (если задан).

---

## 4. Детали маршрута и остановки (`GET /routes/{route_id}`)

Возвращает детальную информацию о выбранном маршруте со списком всех остановок в порядке их следования.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/routes/{route_id}`
- **Параметры пути:**
  - `route_id` *(int, обязательно)*: Идентификатор маршрута (например, `12423`).

### Пример ответа (200 OK)
```json
{
  "route_id": 12423,
  "location_id": 1,
  "name": "33",
  "title": "Мигалово - Гипермаркет Леруа-Мерлен",
  "start_end_stations": "Мигалово - Гипермаркет Леруа-Мерлен",
  "end_station": "Гипермаркет Леруа-Мерлен",
  "vehicle_type_id": 2,
  "is_circular": false,
  "stations": [
    {
      "station_id": 11840,
      "name": "Мигалово",
      "address": "Тверь, улица Громова, 28",
      "lat": 56.843105,
      "lng": 35.801211,
      "location_id": 1,
      "external_id": "134::1",
      "arrival_time": null,
      "agent_id": 0
    },
    {
      "station_id": 11920,
      "name": "Волоколамский путепровод",
      "address": "Тверь, Волоколамский проспект, 45",
      "lat": 56.833641,
      "lng": 35.905041,
      "location_id": 1,
      "external_id": "214::1",
      "arrival_time": null,
      "agent_id": 0
    }
  ]
}
```

---

## 5. Геотрек маршрута для карты (`GET /routes/{route_id}/path`)

Возвращает массив точек геометрии маршрута для отображения непрерывной линии (polyline) на карте.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/routes/{route_id}/path`
- **Параметры пути:**
  - `route_id` *(int, обязательно)*: Идентификатор маршрута.

### Пример ответа (200 OK)
```json
[
  {
    "route_id": 12423,
    "route_path_id": 324397027,
    "order": 1,
    "lat": 56.835858,
    "lng": 35.894705,
    "distance": 0.0
  },
  {
    "route_id": 12423,
    "route_path_id": 324397028,
    "order": 2,
    "lat": 56.835921,
    "lng": 35.894812,
    "distance": 7.3876
  }
]
```

### Описание полей
- `order` *(int)*: Порядковый номер точки трека (1, 2, 3...).
- `lat`, `lng` *(float)*: Координаты точки.
- `distance` *(float)*: Накопленное расстояние в метрах от начала маршрута.

---

## 6. Реестр всех остановок (`GET /stations`)

Возвращает справочник всех остановок региона.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/stations`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[
  {
    "station_id": 11920,
    "name": "Волоколамский путепровод",
    "address": "Тверь, Волоколамский проспект, 45",
    "lat": 56.833641,
    "lng": 35.905041,
    "location_id": 1,
    "external_id": "214::1",
    "arrival_time": null,
    "agent_id": 0
  }
]
```

---

## 7. Информация об остановке (`GET /stations/{station_id}`)

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/stations/{station_id}`
- **Параметры пути:**
  - `station_id` *(int, обязательно)*: ID остановки.

Возвращает объект остановки со структурой, идентичной элементу из `/stations`.

---

## 8. Маршруты и прогноз прибытия на остановку (`GET /stations/{station_id}/routes`)

Возвращает список проходящих через остановку маршрутов и рассчитанный прогноз времени прибытия ближайших рейсов в реальном времени.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/stations/{station_id}/routes`
- **Параметры пути:**
  - `station_id` *(int, обязательно)*: ID остановки.

### Пример ответа (200 OK)
```json
[
  {
    "route_id": 12423,
    "name": "33",
    "end_station": "Ореховая улица",
    "location_id": 1,
    "vehicle_type_id": 2,
    "colour_hex": "",
    "is_circular": false,
    "agent_id": 0,
    "comment": "",
    "estimated_arrival": [
      "2026-09-02T12:04:44+03:00",
      "2026-09-02T12:25:44+03:00"
    ]
  }
]
```

### Описание полей
- `estimated_arrival` *(array of string)*: Массив дат/времени в формате ISO 8601 с прогнозом прибытия ближайших автобусов на эту остановку.

---

## 9. Онлайн позиции транспорта (`GET /vehicles`)

Возвращает телеметрию и текущее местоположение движущихся транспортных средств в заданной географической области (bounding box).

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/vehicles`
- **Query параметры (все 4 обязательны):**
  - `top_lat` *(float)*: Верхняя (северная) широта экрана/области
  - `bottom_lat` *(float)*: Нижняя (южная) широта экрана/области
  - `left_lng` *(float)*: Левая (западная) долгота экрана/области
  - `right_lng` *(float)*: Правая (восточная) долгота экрана/области

*Пример:* `GET /vehicles?top_lat=56.93&bottom_lat=56.78&left_lng=35.73&right_lng=36.03`

### Пример ответа (200 OK)
```json
[
  {
    "vehicle_id": "aef67824-8c92-45f9-8783-0440a1850960",
    "board_number": "10086",
    "license_number": "H325CP69",
    "model": "ЛиАЗ 429260",
    "route_id": 12423,
    "route_name": "33",
    "location_id": 1,
    "vehicle_type_id": 2,
    "lat": 56.80915,
    "lng": 35.872718,
    "speed": 26,
    "course": 199,
    "time_location": "2026-09-02T08:40:20Z",
    "next_station_id": 11920,
    "next_station": {
      "station_id": 11920,
      "name": "Волоколамский путепровод",
      "address": "Тверь, Волоколамский проспект, 45",
      "lat": 56.833641,
      "lng": 35.905041,
      "location_id": 1,
      "external_id": "214::1"
    },
    "qr_vehicle_id": 336,
    "qr_vehicle": {
      "qr_vehicle_id": 336,
      "qr_number": "69-0336",
      "qr_uuid": "aef67824-8c92-45f9-8783-0440a1850960",
      "location_id": 1
    },
    "carrier": {
      "carrier_id": 1,
      "name": "ООО \"Верхневолжское автотранспортное предприятие\"",
      "tn_ticket_park_id": "0002",
      "tn_ticket_location_id": ""
    },
    "beacons": [
      {
        "beacon_id": 264,
        "beacon_uuid": "cfae197b-b18e-40d1-b3c9-462c9c001357",
        "beacon_major": "264",
        "beacon_minor": "1"
      }
    ]
  }
]
```

### Описание полей
- `vehicle_id` *(string)*: Идентификатор борта в системе диспетчеризации.
- `board_number` *(string)*: Гаражный/бортовой номер автобуса.
- `license_number` *(string)*: Государственный регистрационный знак (госномер).
- `model` *(string)*: Марка и модель автобуса.
- `route_id`, `route_name` *(int, string)*: Номер и ID текущего выполняемого маршрута.
- `lat`, `lng` *(float)*: Текущие координаты автобуса.
- `speed` *(int)*: Текущая скорость (км/ч).
- `course` *(int)*: Направление движения в градусах (0–359°).
- `time_location` *(string)*: Время последней телеметрии по GPS/ГЛОНАСС.
- `next_station_id`, `next_station` *(object)*: Ближайшая следующая остановка по маршруту.
- `qr_vehicle` *(object)*: Данные QR-кода наклейки в салоне автобуса:
  - `qr_number`: Номер QR-кода (например, `"69-0336"`).
- `beacons` *(array)*: Список BLE маячков для автоматической посадки пассажира.
- `carrier` *(object)*: Данные компании-перевозчика.

---

## 10. Список Bluetooth-маячков (`GET /beacons`)

Возвращает реестр всех BLE (Bluetooth Low Energy) маячков iBeacon, привязанных к подвижному составу. Используются клиентом для автоопределения автобуса при входе в салон.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/beacons`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[
  {
    "beacon_id": 331,
    "beacon_uuid": "cfae197b-b18e-40d1-b3c9-462c9c001357",
    "beacon_major": "331",
    "beacon_minor": "1"
  }
]
```

---

## 11. Оповещения и предупреждения (`GET /alerts`)

Возвращает список действующих экстренных оповещений, перекрытий движения и системных новостей.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/alerts`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
[]
```

---

## 12. Конфигурация клиента (`GET /config`)

Возвращает конфигурационные флаги возможностей для мобильного приложения.

- **URL:** `GET https://api.merlin.tvercard.ru/api/client/v1/config`
- **Параметры:** Нет

### Пример ответа (200 OK)
```json
{
  "1": {
    "feature1": false
  }
}
```

---

## 13. Покупка билета (`POST /tickets/buy`)

Инициализация покупки электронного билета в салоне автобуса через QR-код или выбор маршрута.

- **URL:** `POST https://api.merlin.tvercard.ru/api/client/v1/tickets/buy`
- **Заголовки:**
  - `Content-Type: application/json`
  - Подпись запроса (`X-Signature` или токен авторизации)
- **Тело запроса (JSON):**
  ```json
  {
    "passenger_id": 12345,
    "route_id": 12423,
    "vehicle_id": "aef67824-8c92-45f9-8783-0440a1850960"
  }
  ```

---

## 14. Билеты пассажира (`GET /tickets`, `GET /tickets/active`, `GET /tickets/history`)

Эндпоинты для получения купленных билетов и истории поездок пассажира (требуют авторизации пассажира).

- `GET /tickets` — Общий список билетов.
- `GET /tickets/active` — Активные (действующие на текущую поездку) билеты.
- `GET /tickets/history` — История завершенных поездок.

---

## Коды ошибок

| Код | Описание |
|---|---|
| `200 OK` | Запрос успешно обработан. |
| `400 Bad Request` | Неправильные параметры запроса (например, отсутствуют границы координат в `/vehicles`). Ошибка возвращается в виде `{"code": 400, "message": "Неправильный запрос к серверу"}` или `{"code": 10, "message": "Пассажир не найден"}`. |
| `403 Forbidden` | Недействительная или отсутствующая цифровая подпись запроса (`{"code": 1, "message": "Неправильная подпись"}`). |
| `404 Not Found` | Запрашиваемый ресурс или маршрут не найден. |
| `500 Internal Error` | Внутренняя ошибка сервера. |
