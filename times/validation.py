from rest_framework.response import Response
from rest_framework import status

VALID_MADHABS = {'hanafi', 'shafi'}
VALID_CITIES = {'colombo', 'others'}


def validate_madhab_city(madhab: str, city: str):
    """Validate madhab and city. Returns (madhab, city, error_response)."""
    m = (madhab or 'shafi').lower()
    c = (city or 'colombo').lower()

    if m not in VALID_MADHABS:
        return None, None, Response(
            data={
                'error': f'Invalid madhab: {m}',
                'valid_values': sorted(list(VALID_MADHABS)),
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if c not in VALID_CITIES:
        return None, None, Response(
            data={
                'error': f'Invalid city: {c}',
                'valid_values': sorted(list(VALID_CITIES)),
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    return m, c, None
