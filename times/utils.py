import json
from datetime import date, datetime
from pathlib import Path
from typing import Dict, Optional

import pytz

from .datamodels import PrayerTimes, PrayerEvent

PRAYERS = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]

BASE_DIR = Path(__file__).resolve().parent.parent  # project root
DATA_DIR = BASE_DIR / 'prayer_api' / 'data_lk'

LANKA_TZ = pytz.timezone('Asia/Colombo')

# 🔑 Adjust this if your dataset year is fixed (e.g. 2025)
SUPPORTED_YEAR = date.today().year


class PrayerDataNotAvailable(Exception):
    """Raised when prayer data is not available for the requested date."""
    pass


def load_table(madhab: str, city: str):
    file_path = DATA_DIR / f"{madhab}.{city}.json"
    with open(file_path, encoding='utf-8') as f:
        return json.load(f)


def minutes_to_hhmm(minutes: int) -> str:
    hours = minutes // 60
    minutes %= 60
    return f"{hours:02d}:{minutes:02d}"


def get_times_for_day(d: date, madhab: str, city: str) -> PrayerTimes:
    """
    Look up the prayer times for a given date, madhab, and city.

    - d: Python date object (e.g. date.today())
    - madhab: "hanafi" or "shafi"
    - city: "colombo" or "others"

    Raises PrayerDataNotAvailable if the year is not supported.
    """

    if d.year != SUPPORTED_YEAR:
        raise PrayerDataNotAvailable(
            f"No data available for year {d.year} in {madhab}.{city}"
        )

    table = load_table(madhab, city)

    # Calculating indices for month/day (JSON is zero-based, Python dates are one-based)
    month_index = d.month - 1
    day_index = d.day - 1

    try:
        times_in_minutes = table[month_index][day_index]
    except IndexError:
        raise PrayerDataNotAvailable(
            f"No data available for {d} in {madhab}.{city}"
        )

    times_dict: Dict[str, str] = {}
    for i, prayer in enumerate(PRAYERS):
        minutes = times_in_minutes[i]
        times_dict[prayer] = minutes_to_hhmm(minutes)

    return PrayerTimes(
        date=d,
        madhab=madhab,
        city=city,
        **times_dict
    )


def next_prayer(dt: datetime, times: PrayerTimes) -> Optional[PrayerEvent]:
    if dt.tzinfo is None:
        dt = LANKA_TZ.localize(dt)
    else:
        dt = dt.astimezone(LANKA_TZ)

    for name, hhmm in times.as_dict().items():
        prayer_dt = LANKA_TZ.localize(
            datetime.strptime(f'{times.date} {hhmm}', '%Y-%m-%d %H:%M')
        )
        if prayer_dt > dt:
            return PrayerEvent(
                given_datetime=dt,
                name=name,
                time=prayer_dt,
                madhab=times.madhab,
                city=times.city,
            )
    return None


def previous_prayer(dt: datetime, times: PrayerTimes) -> Optional[PrayerEvent]:
    if dt.tzinfo is None:
        dt = LANKA_TZ.localize(dt)
    else:
        dt = dt.astimezone(LANKA_TZ)

    prev = None
    for name, hhmm in times.as_dict().items():
        prayer_dt = LANKA_TZ.localize(
            datetime.strptime(f'{times.date} {hhmm}', '%Y-%m-%d %H:%M')
        )
        if prayer_dt < dt:
            prev = PrayerEvent(
                given_datetime=dt,
                name=name,
                time=prayer_dt,
                madhab=times.madhab,
                city=times.city,
            )
        else:
            break
    return prev
