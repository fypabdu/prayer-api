# Repository Guidelines

## Project Structure & Module Organization
- `prayer_api/` holds the Django project settings, URL routing, and WSGI/ASGI entrypoints.
- `times/` is the main app with API views, serializers, validation, and utilities.
- `times/tests/` contains API tests (`test_*.py`) built on DRF’s `APITestCase`.
- `prayer_api/data_lk/` stores the JSON prayer-time datasets used by the API.
- `infra/` contains Terraform files for deployment infrastructure.
- Top-level `manage.py` is the dev entrypoint; `Dockerfile` builds a container image.

## Build, Test, and Development Commands
- `python -m venv .venv && source .venv/bin/activate` creates/activates a local venv.
- `pip install -r requirements.txt` installs runtime dependencies.
- `python manage.py migrate` prepares the default SQLite DB.
- `python manage.py runserver` starts the dev server at `http://127.0.0.1:8000/`.
- `python manage.py test times` runs the app’s API tests.
- `docker build -t prayer-api .` builds the Docker image; `docker run -p 8000:8000 prayer-api` runs it.

## Coding Style & Naming Conventions
- Python uses 4-space indentation and standard PEP 8 naming.
- Modules/files use `snake_case`; classes use `PascalCase`; constants use `UPPER_SNAKE_CASE`.
- API endpoints and serializers should follow existing patterns in `times/views.py` and `times/serializers.py`.
- No formatter/linter is configured; keep changes small and readable.

## Testing Guidelines
- Tests live in `times/tests/` and should be named `test_*.py` with `test_*` methods.
- Prefer DRF’s `APITestCase` for endpoint coverage and assert HTTP status + payload shape.
- When adding endpoints, add success and error-path cases mirroring existing tests.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commits (e.g., `feat(api): add range filter`).
- PRs should include a concise summary, testing notes, and any API behavior changes.
- If endpoints or payloads change, mention the affected paths and example requests.

## Configuration & Data Notes
- Settings live in `prayer_api/settings.py`; dev runs with SQLite and `DEBUG=True` by default.
- Data files in `prayer_api/data_lk/` are treated as source-of-truth; update them alongside tests.
