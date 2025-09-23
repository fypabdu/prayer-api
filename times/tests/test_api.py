from datetime import date, datetime
from rest_framework.test import APITestCase
from rest_framework import status


class TestPrayerTimesAPI(APITestCase):

    def test_today_times_valid(self):
        response = self.client.get('/api/v1/times/today/', {'madhab': 'shafi', 'city': 'colombo'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['madhab'], 'shafi')
        self.assertIn('fajr', data['times'])

    def test_today_times_invalid_madhab(self):
        response = self.client.get('/api/v1/times/today/', {'madhab': 'maliki', 'city': 'colombo'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.json())

    def test_today_times_invalid_city(self):
        response = self.client.get('/api/v1/times/today/', {'madhab': 'hanafi', 'city': 'kandy'})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('error', response.json())

    def test_date_times_valid(self):
        response = self.client.get('/api/v1/times/date/', {
            'madhab': 'hanafi', 'city': 'others', 'date': '2025-09-23'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['date'], '2025-09-23')

    def test_date_times_invalid_format(self):
        response = self.client.get('/api/v1/times/date/', {
            'madhab': 'hanafi', 'city': 'others', 'date': '23-09-2025'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_date_times_out_of_range(self):
        # December 32 does not exist
        response = self.client.get('/api/v1/times/date/', {
            'madhab': 'shafi', 'city': 'colombo', 'date': '2025-12-32'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_next_times_valid(self):
        dt = datetime.now().replace(hour=15, minute=30).isoformat(timespec='minutes')
        response = self.client.get('/api/v1/times/next/', {
            'madhab': 'shafi', 'city': 'colombo', 'datetime': dt
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('next_prayer', response.json())

    def test_next_times_invalid_datetime(self):
        response = self.client.get('/api/v1/times/next/', {
            'madhab': 'hanafi', 'city': 'colombo', 'datetime': 'notadatetime'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_range_times_valid(self):
        response = self.client.get('/api/v1/times/range/', {
            'madhab': 'shafi', 'city': 'colombo',
            'start': '2025-09-20', 'end': '2025-09-22'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.json()['results']), 3)

    def test_range_times_end_before_start(self):
        response = self.client.get('/api/v1/times/range/', {
            'madhab': 'shafi', 'city': 'colombo',
            'start': '2025-09-23', 'end': '2025-09-20'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_range_times_missing_params(self):
        response = self.client.get('/api/v1/times/range/', {
            'madhab': 'shafi', 'city': 'colombo'
        })
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_date_times_not_available(self):
        """Request a date far outside the dataset → should return 404."""
        response = self.client.get(
            '/api/v1/times/date/',
            {'madhab': 'shafi', 'city': 'colombo', 'date': '2100-01-01'}
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn('error', response.json())
        self.assertIn('No data available', response.json()['error'])

    def test_next_times_not_available(self):
        """Request datetime in a year not in JSON → should return 404."""
        response = self.client.get(
            '/api/v1/times/next/',
            {'madhab': 'shafi', 'city': 'colombo', 'datetime': '2100-01-01T12:00'}
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn('error', response.json())

    def test_range_times_not_available(self):
        """Request a range that includes dates outside dataset → should include errors in results."""
        response = self.client.get(
            '/api/v1/times/range/',
            {'madhab': 'shafi', 'city': 'colombo', 'start': '2099-12-30', 'end': '2100-01-02'}
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertEqual(data['madhab'], 'shafi')
        self.assertEqual(data['city'], 'colombo')

        # At least one result should contain an error
        error_results = [r for r in data['results'] if 'error' in r.get('times', {})]
        self.assertTrue(len(error_results) > 0)