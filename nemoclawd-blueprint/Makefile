.PHONY: lint format check test

lint:
	ruff check .

format:
	ruff format .
	ruff check --fix .

check:
	ruff check .
	ruff format --check .
	PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests

test:
	PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests
