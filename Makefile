.PHONY: validate contracts lint test smoke

validate:
	python scripts/validate_openapi.py apis/openapi/payment-api.yaml
	python scripts/validate_asyncapi.py apis/asyncapi/payment-events.yaml

lint:
	cd tools/contract-lint && npm ci --no-audit --no-fund && npm run lint

test:
	python -m pytest -q runtime/e2e/payment-api/tests

contracts: validate lint test

smoke:
	python scripts/smoke_test.py
