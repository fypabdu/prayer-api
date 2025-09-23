from rest_framework import serializers


class PrayerTimesSerializer(serializers.Serializer):
    date = serializers.DateField()
    madhab = serializers.CharField()
    city = serializers.CharField()
    times = serializers.DictField(
        child=serializers.CharField(),
        help_text='Mapping of prayer name -> time (HH:MM)'
    )


class PrayerEventSerializer(serializers.Serializer):
    given_datetime = serializers.DateTimeField(
        required=False,
        help_text='Datetime used as the reference point'
    )
    madhab = serializers.CharField()
    city = serializers.CharField()
    next_prayer = serializers.DictField(
        child=serializers.CharField(),
        help_text='Example: {"name": "asr", "time": "15:45"}',
        required=False
    )
    message = serializers.CharField(required=False)


class PrayerTimesRangeSerializer(serializers.Serializer):
    start = serializers.DateField()
    end = serializers.DateField()
    madhab = serializers.CharField()
    city = serializers.CharField()
    results = PrayerTimesSerializer(many=True)
