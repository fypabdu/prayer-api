from datetime import date, datetime, timedelta

from drf_spectacular.utils import OpenApiExample, OpenApiParameter, extend_schema
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from rest_framework.status import HTTP_400_BAD_REQUEST, HTTP_500_INTERNAL_SERVER_ERROR

from .utils import get_times_for_day, next_prayer, PrayerDataNotAvailable
from .validation import validate_madhab_city
from .serializers import PrayerTimesSerializer, PrayerEventSerializer, PrayerTimesRangeSerializer


@extend_schema(
    summary='Get today’s prayer times',
    description='Returns the prayer times for today for a given madhab and city.',
    parameters=[
        OpenApiParameter(
            name='madhab',
            description='School of thought. Valid values: hanafi, shafi',
            required=False,
            type=str,
            examples=[OpenApiExample('Hanafi Example', value='hanafi')],
        ),
        OpenApiParameter(
            name='city',
            description='City name. Valid values: colombo, others',
            required=False,
            type=str,
            examples=[OpenApiExample('Colombo Example', value='colombo')],
        ),
    ],
    responses={200: PrayerTimesSerializer},
)
@api_view(['GET'])
def today_times(request):
    madhab, city, error = validate_madhab_city(
        request.query_params.get('madhab'),
        request.query_params.get('city'),
    )
    if error:
        return error

    try:
        prayer_times = get_times_for_day(date.today(), madhab, city)
    except PrayerDataNotAvailable as e:
        return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=HTTP_500_INTERNAL_SERVER_ERROR)

    serializer = PrayerTimesSerializer(prayer_times)
    return Response(serializer.data, status=status.HTTP_200_OK)


@extend_schema(
    summary='Get prayer times for a specific date',
    description='Pass a date in YYYY-MM-DD format along with madhab and city.',
    parameters=[
        OpenApiParameter('madhab', str, description='hanafi or shafi'),
        OpenApiParameter('city', str, description='colombo or others'),
        OpenApiParameter('date', str, description='Date in YYYY-MM-DD format', required=True,
                         examples=[OpenApiExample('Example date', value='2025-09-23')]),
    ],
    responses={200: dict},
)
@api_view(['GET'])
def date_times(request):
    madhab, city, error = validate_madhab_city(
        request.query_params.get('madhab'),
        request.query_params.get('city'),
    )
    if error:
        return error

    date_str = request.query_params.get('date')
    if not date_str:
        return Response(
            {'error': 'Missing "date" query param (YYYY-MM-DD)'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        d = date.fromisoformat(date_str)
        prayer_times = get_times_for_day(d, madhab, city)
    except ValueError:
        return Response({'error': 'Invalid date format. Use YYYY-MM-DD'}, status=HTTP_400_BAD_REQUEST)
    except PrayerDataNotAvailable as e:
        return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=HTTP_500_INTERNAL_SERVER_ERROR)

    serializer = PrayerTimesSerializer(prayer_times)
    return Response(serializer.data, status=status.HTTP_200_OK)


@extend_schema(
    summary='Get next prayer after a given datetime',
    description='Provide a datetime in ISO8601 format (YYYY-MM-DDTHH:MM).',
    parameters=[
        OpenApiParameter('madhab', str, description='hanafi or shafi'),
        OpenApiParameter('city', str, description='colombo or others'),
        OpenApiParameter('datetime', str, required=True,
                         description='Datetime in ISO8601 format (YYYY-MM-DDTHH:MM)',
                         examples=[OpenApiExample('Example', value='2025-09-23T15:45')]),
    ],
    responses={200: PrayerEventSerializer},
)
@api_view(['GET'])
def next_times(request):
    madhab, city, error = validate_madhab_city(
        request.query_params.get('madhab'),
        request.query_params.get('city'),
    )
    if error:
        return error

    dt_str = request.query_params.get('datetime')
    if not dt_str:
        return Response(
            {'error': 'Missing "datetime" query param (ISO 8601 e.g. 2025-09-23T15:45)'},
            status=HTTP_400_BAD_REQUEST,
        )

    try:
        dt = datetime.fromisoformat(dt_str)
        prayer_times = get_times_for_day(dt.date(), madhab, city)
        next_prayer_event = next_prayer(dt, prayer_times)
    except ValueError:
        return Response({'error': 'Invalid datetime format. Use YYYY-MM-DDTHH:MM'}, status=HTTP_400_BAD_REQUEST)
    except PrayerDataNotAvailable as e:
        return Response({'error': str(e)}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=HTTP_500_INTERNAL_SERVER_ERROR)

    if not next_prayer_event:
        return Response({
            'message': 'No prayers left today. Next is Fajr tomorrow.',
            'given_datetime': dt_str,
            'madhab': madhab,
            'city': city,
        }, status=status.HTTP_200_OK)

    data = {
        'given_datetime': dt.isoformat(),
        'madhab': madhab,
        'city': city,
        'next_prayer': {
            'name': next_prayer_event.name,
            'time': next_prayer_event.time.strftime("%H:%M"),
        }
    }
    serializer = PrayerEventSerializer(data)
    return Response(serializer.data, status=status.HTTP_200_OK)


@extend_schema(
    summary='Get prayer times for a date range',
    description='Provide start and end dates (YYYY-MM-DD).',
    parameters=[
        OpenApiParameter(name='madhab', description='hanafi or shafi', type=str),
        OpenApiParameter(name='city', description='colombo or others', type=str),
        OpenApiParameter(name='start', description='Start date YYYY-MM-DD', type=str, required=True),
        OpenApiParameter(name='end', description='End date YYYY-MM-DD', type=str, required=True),
    ],
    responses={200: PrayerTimesRangeSerializer},
)
@api_view(['GET'])
def range_times(request):
    madhab, city, error = validate_madhab_city(
        request.query_params.get('madhab'),
        request.query_params.get('city'),
    )
    if error:
        return error

    start_str = request.query_params.get('start')
    end_str = request.query_params.get('end')
    if not start_str or not end_str:
        return Response(
            {'error': 'Missing "start" or "end" query params (YYYY-MM-DD)'},
            status=HTTP_400_BAD_REQUEST,
        )

    try:
        start_date = date.fromisoformat(start_str)
        end_date = date.fromisoformat(end_str)
        if end_date < start_date:
            return Response({'error': '"end" must not be earlier than "start"'}, status=HTTP_400_BAD_REQUEST)
    except ValueError:
        return Response({'error': 'Dates must be in YYYY-MM-DD format'}, status=HTTP_400_BAD_REQUEST)

    results = []
    current = start_date
    while current <= end_date:
        try:
            pt = get_times_for_day(current, madhab, city)
            results.append(pt)
        except PrayerDataNotAvailable as e:
            results.append({
                'date': str(current),
                'madhab': madhab,
                'city': city,
                'times': {'error': str(e)}
            })
        except Exception as e:
            results.append({
                'date': str(current),
                'madhab': madhab,
                'city': city,
                'times': {'error': str(e)}
            })
        current += timedelta(days=1)

    serializer = PrayerTimesRangeSerializer({
        'start': start_date,
        'end': end_date,
        'madhab': madhab,
        'city': city,
        'results': results,
    })
    return Response(serializer.data, status=status.HTTP_200_OK)
