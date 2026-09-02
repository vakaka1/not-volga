#!/usr/bin/env python3
"""
Скрипт для парсинга и обновления тарифов с сайта https://tvercard.ru/tarify/
Поддерживает регионы:
  - Тверь и Калининский район
  - Ржев
  - Старица
  - Кимры
  - Зубцов
  - Конаково

Может запускаться как локально, так и через GitHub Actions (Cron).
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

BASE_URL = "https://tvercard.ru/tarify"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7",
}

REGIONS_CONFIG = [
    {
        "id": "tver",
        "name": "Тверь и Калининский район",
        "district_name": "Калининский район",
        "location_id": 1,
        "path": "/",
        "transfer_duration_default": 60,
    },
    {
        "id": "rzhev",
        "name": "Ржев",
        "district_name": "Ржевский район",
        "location_id": 2,
        "path": "/rzhev/",
        "transfer_duration_default": 30,
    },
    {
        "id": "staritsa",
        "name": "Старица",
        "district_name": "Старицкий район",
        "location_id": 6,
        "path": "/staritsa/",
        "transfer_duration_default": 30,
    },
    {
        "id": "kimry",
        "name": "Кимры",
        "district_name": "Кимрский район",
        "location_id": 5,
        "path": "/kimry/",
        "transfer_duration_default": 30,
    },
    {
        "id": "zubtsov",
        "name": "Зубцов",
        "district_name": "Зубцовский район",
        "location_id": 7,
        "path": "/zubtsov/",
        "transfer_duration_default": 30,
    },
    {
        "id": "konakovo",
        "name": "Конаково",
        "district_name": "Конаковский район",
        "location_id": 8,
        "path": "/konakovo/",
        "transfer_duration_default": 30,
    },
]

# Базовые тарифы на абонементы (поездки и дни) для Верхневолжья
DEFAULT_TRIPS_PASSES = [
    {"trips": 5, "duration_days": 30, "price": 190.0, "price_per_trip": 38.0},
    {"trips": 20, "duration_days": 60, "price": 740.0, "price_per_trip": 37.0},
    {"trips": 40, "duration_days": 90, "price": 1440.0, "price_per_trip": 36.0},
    {"trips": 60, "duration_days": 120, "price": 2100.0, "price_per_trip": 35.0},
]

DEFAULT_DAYS_PASSES = [
    {"days": 1, "price": 140.0},
    {"days": 3, "price": 360.0},
    {"days": 7, "price": 600.0},
    {"days": 15, "price": 1150.0},
    {"days": 30, "price": 1800.0},
    {"days": 90, "price": 5000.0},
    {"days": 365, "price": 18000.0},
]


import time


def fetch_url(url: str, timeout: int = 15, max_retries: int = 3) -> str:
    """Загружает содержимое страницы по URL с повторными попытками."""
    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as response:
                charset = response.headers.get_content_charset() or "utf-8"
                return response.read().decode(charset, errors="replace")
        except Exception as e:
            if attempt == max_retries:
                raise
            time.sleep(1.0 * attempt)
    raise RuntimeError(f"Failed to fetch {url}")


def clean_number(text: str) -> float:
    """Преобразует строку с числом ('4,75', '525', ' 40 ') в float."""
    cleaned = text.replace(",", ".").replace(" ", "").replace("\xa0", "").strip()
    return float(cleaned)


def parse_region_page(html: str, config: dict) -> dict:
    """Парсит HTML-страницу тарифов для конкретного региона."""
    result = {
        "id": config["id"],
        "name": config["name"],
        "location_id": config["location_id"],
        "city": {
            "single_ride": {
                "cashless": 40.0,
                "cash": 45.0,
                "app_qr": 40.0,
            },
            "transfer": {
                "duration_minutes": config["transfer_duration_default"],
                "first_ride_price": 40.0,
                "transfer_price": 20.0,
                "total_price": 60.0,
                "description": "разовая поездка + пересадка в городской зоне",
            },
            "school_pass": {
                "price": 525.0,
                "valid_period": "01.09.25 - 04.05.26",
                "period_type": "calendar_month",
                "description": "Действует в черте города для школьников",
            },
            "social_pass": {
                "price": 302.0,
                "period_type": "calendar_month",
                "description": "Социальная карта жителя Тверской области",
            },
            "trips_passes": DEFAULT_TRIPS_PASSES,
            "days_passes": DEFAULT_DAYS_PASSES,
        },
        "suburban": {
            "district_name": config["district_name"],
            "per_km_cashless": 4.75,
            "per_km_cash": 4.85,
        },
    }

    if not html:
        return result

    # 1. Школьный абонемент
    school_match = re.search(
        r"Школьный абонемент.*?<b>([\d\s,.]+)</b>", html, re.DOTALL | re.IGNORECASE
    )
    if school_match:
        try:
            result["city"]["school_pass"]["price"] = clean_number(school_match.group(1))
        except ValueError:
            pass

    valid_period_match = re.search(
        r"Действителен для покупки с\s*([\d.]+)\s*по\s*([\d.]+)", html, re.IGNORECASE
    )
    if valid_period_match:
        start_p = valid_period_match.group(1).rstrip(".")
        end_p = valid_period_match.group(2).rstrip(".")
        result["city"]["school_pass"]["valid_period"] = f"{start_p} - {end_p}"

    # 2. Льготный абонемент
    social_match = re.search(
        r"Льготный абонемент.*?<b>([\d\s,.]+)</b>", html, re.DOTALL | re.IGNORECASE
    )
    if social_match:
        try:
            result["city"]["social_pass"]["price"] = clean_number(social_match.group(1))
        except ValueError:
            pass

    # 3. Пересадочный тариф (ищем строго внутри блока пересадочного тарифа)
    transfer_sec_match = re.search(
        r"Пересадочный тариф(.*?)(?:<h2>|template|$)", html, re.DOTALL | re.IGNORECASE
    )
    if transfer_sec_match:
        transfer_sec = transfer_sec_match.group(1)
        mins_match = re.search(r"<b>(\d+)</b>\s*мин", transfer_sec, re.IGNORECASE)
        if mins_match:
            try:
                result["city"]["transfer"]["duration_minutes"] = int(mins_match.group(1))
            except ValueError:
                pass

        transfer_price_match = re.search(
            r"<b>([\d,.]+)</b>\s*<span[^>]*>[^<]*₽[^<]*</span>\s*\+\s*<b>([\d,.]+)</b>",
            transfer_sec,
            re.DOTALL | re.IGNORECASE,
        )
        if transfer_price_match:
            try:
                first = clean_number(transfer_price_match.group(1))
                second = clean_number(transfer_price_match.group(2))
                result["city"]["transfer"]["first_ride_price"] = first
                result["city"]["transfer"]["transfer_price"] = second
                result["city"]["transfer"]["total_price"] = first + second
                result["city"]["single_ride"]["cashless"] = first
                result["city"]["single_ride"]["app_qr"] = first
            except ValueError:
                pass

    # 4. Пригородный тариф (ищем внутри блока Пригород)
    suburban_sec_match = re.search(
        r"Пригород(.*?)(?:Рассчитать|<template|$)", html, re.DOTALL | re.IGNORECASE
    )
    if suburban_sec_match:
        suburban_sec = suburban_sec_match.group(1)
        cards = re.findall(
            r"<div[^>]*class=['\"][^'\"]*(?:tariff-card|item)[^'\"]*['\"][^>]*>(.*?)</div>\s*</div>",
            suburban_sec,
            re.DOTALL,
        )
        for card in cards:
            val_match = re.search(r"<b>([\d,.]+)", card)
            if not val_match:
                continue
            val = clean_number(val_match.group(1))
            if "безналичн" in card:
                result["suburban"]["per_km_cashless"] = val
            elif "наличн" in card:
                result["suburban"]["per_km_cash"] = val

    return result


def main():
    print("=== Обновление тарифов NOT-Volga ===")
    regions_data = []

    for config in REGIONS_CONFIG:
        url = f"{BASE_URL}{config['path']}"
        print(f"Загрузка тарифов для '{config['name']}' ({url})...")
        try:
            html = fetch_url(url)
            region_tariff = parse_region_page(html, config)
            regions_data.append(region_tariff)
            print(f" -> Успешно. Школьный: {region_tariff['city']['school_pass']['price']} ₽, "
                  f"Льготный: {region_tariff['city']['social_pass']['price']} ₽, "
                  f"Пересадка: {region_tariff['city']['transfer']['duration_minutes']} мин, "
                  f"Пригород: {region_tariff['suburban']['per_km_cashless']} ₽/км")
        except Exception as e:
            print(f" -> Ошибка загрузки {url}: {e}. Используются базовые значения.")
            fallback_tariff = parse_region_page("", config)
            regions_data.append(fallback_tariff)

    full_payload = {
        "meta": {
            "version": "1.0.0",
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "source": BASE_URL,
            "currency": "RUB",
            "total_regions": len(regions_data),
        },
        "regions": regions_data,
    }

    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    server_json_path = os.path.join(repo_root, "server", "tariffs.json")
    assets_json_path = os.path.join(repo_root, "assets", "data", "tariffs.json")

    os.makedirs(os.path.dirname(server_json_path), exist_ok=True)
    with open(server_json_path, "w", encoding="utf-8") as f:
        json.dump(full_payload, f, ensure_ascii=False, indent=2)
    print(f"\nСохранено в {server_json_path}")

    os.makedirs(os.path.dirname(assets_json_path), exist_ok=True)
    with open(assets_json_path, "w", encoding="utf-8") as f:
        json.dump(full_payload, f, ensure_ascii=False, indent=2)
    print(f"Копия сохранена для оффлайн-клиента в {assets_json_path}")

    print("\nТарифы успешно обновлены!")


if __name__ == "__main__":
    main()
