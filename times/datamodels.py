from dataclasses import dataclass
from datetime import date, datetime
from typing import Dict, Optional


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
    tahajjud: Optional[str] = None
    midnight: Optional[str] = None

    @property
    def times(self) -> Dict[str, str]:
        base = {
            'fajr': self.fajr,
            'sunrise': self.sunrise,
            'dhuhr': self.dhuhr,
            'asr': self.asr,
            'maghrib': self.maghrib,
            'isha': self.isha,
        }

        if self.tahajjud:
            base['tahajjud'] = self.tahajjud
        if self.midnight:
            base['midnight'] = self.midnight
        return base


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
