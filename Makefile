.PHONY: validate contracts smoke

validate:
	python scripts/validate_openapi.py apis/openapi/payment-api.yaml

contracts: validate

smoke:
	python scripts/smoke_test.py
