# Prayer Times API Sri Lanka

[![Python Version](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/downloads/release/python-3120/)
[![CI/CD](https://github.com/fypabdu/prayer-api/actions/workflows/ci.yml/badge.svg)](https://github.com/fypabdu/prayer-api/actions/workflows/ci.yml)
[![Docker Hub](https://img.shields.io/docker/v/abu99/prayer-api?sort=semver)](https://hub.docker.com/r/abu99/prayer-api)
[![codecov](https://codecov.io/gh/fypabdu/prayer-api/branch/main/graph/badge.svg?token=<CODECOV_TOKEN>)](https://codecov.io/gh/fypabdu/prayer-api)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This is a lightweight Django + DRF API that serves prayer times for Sri Lanka.  
The dataset comes from [`prayer-time-lk`](https://github.com/thani-sh/prayer-time-lk/tree/main/data), and I’ve wrapped it in a clean, documented REST API with OpenAPI/Swagger out of the box.

Latest deployment: [`http://prayer-api-lb-1574385576.us-east-1.elb.amazonaws.com/api/v1/docs/swagger/`](http://prayer-api-lb-1574385576.us-east-1.elb.amazonaws.com/api/v1/docs/swagger/)


---

## ✨ Features

- 🕌 **Prayer times API**  
  - Get today’s prayer times  
  - Get times for a specific date  
  - Get the next prayer after a given datetime  
  - Get times for a date range  

- 🧑‍💻 **Developer friendly**  
  - Built with Django REST Framework  
  - Auto-generated Swagger docs via drf-spectacular  
  - Structured datamodels with serializers + tests  

- ✅ **Tests included**  
  - Unit tests for all endpoints  
  - Covers valid/invalid input and dataset edge cases  

---

## 🚀 Getting Started

### 1. Clone and install
```bash
git clone https://github.com/YOUR_USERNAME/prayer-api.git
cd prayer-api
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```

### 2. Run Migrations

```bash
python manage.py migrate
```

### 3. Run the Server
```bash
python manage.py runserver
```

### 4. Run the tests
```bash
python manage.py test times
```

## 📡 API Endpoints
### Today’s Times
```bash
GET /api/v1/times/today/?madhab=shafi&city=colombo
```

### Times for a Specific Date
```bash
GET /api/v1/times/date/?madhab=hanafi&city=others&date=2025-09-23
```

### Next Prayer
```bash
GET /api/v1/times/next/?madhab=shafi&city=colombo&datetime=2025-09-23T15:45
```

### Times for a Date Range
```bash
GET /api/v1/times/range/?madhab=shafi&city=colombo&start=2025-09-20&end=2025-09-22
```

### Swagger/OpenAPI Docs
```bash
/api/schema/swagger-ui/
```


## 🛠 Tech Stack

* Python 3.12
* Django 5
* Django REST Framework
* drf-spectacular (for OpenAPI docs)
* Pytest / DRF test client
* pytz (timezone handling)

## 📦 Deployment


* AWS Lambda (serverless)
* Terraform (IaC) for infra
* GitHub Actions (CI/CD) for tests + deployments
* Route53 for DNS if you want a nice URL


## 🤝 Contributing 

PRs and suggestions welcome! Please make sure tests are green before submitting.


## 📄 License
MIT — use it, hack it, share it.

