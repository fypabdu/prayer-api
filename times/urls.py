from django.urls import path
from . import views

urlpatterns = [
    path('times/today/', views.today_times),
    path('times/date/', views.date_times),
    path('times/next/', views.next_times),
    path('times/range/', views.range_times),
]