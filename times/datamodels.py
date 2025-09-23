from dataclasses import dataclass
from datetime import date, datetime
from typing import Dict


@dataclass
class PrayerTimes:
    date: date
    madhab: str
    city: str
    fajr: str
    sunrise: str
    dhuhr: str
    asr: str
    maghrib: str
    isha: str

    @property
    def times(self) -> Dict[str, str]:
        return {
            'fajr': self.fajr,
            'sunrise': self.sunrise,
            'dhuhr': self.dhuhr,
            'asr': self.asr,
            'maghrib': self.maghrib,
            'isha': self.isha,
        }

    def as_dict(self) -> Dict[str, str]:
        return self.times


@dataclass
class PrayerEvent:
    """Represents a single prayer event relative to a given datetime."""
    given_datetime: datetime
    name: str
    time: datetime
    madhab: str
    city: str
