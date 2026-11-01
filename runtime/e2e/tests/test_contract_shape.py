"""Check that the API contract reflects executed payload and response shapes."""
from pathlib import Path
import unittest

import jsonschema
import yaml


ROOT = Path(__file__).resolve().parents[3]
DOC = yaml.safe_load((ROOT / "apis/openapi/payment-api.yaml").read_text(encoding="utf-8"))


def schema(name):
    # Keep local OpenAPI components in the root for the internal $ref resolution.
    return {
        **DOC["components"]["schemas"][name],
        "components": DOC["components"],
    }


class ContractShapeTests(unittest.TestCase):
    def test_machine_to_machine_flow_declared(self):
        scheme = DOC["components"]["securitySchemes"]["oauth2"]
        self.assertIn("clientCredentials", scheme["flows"])
        self.assertIn("payments.read", scheme["flows"]["clientCredentials"]["scopes"])

    def test_request_schema_rejects_extra_and_invalid_money(self):
        validator = jsonschema.Draft202012Validator(schema("PaymentRequest"))
        valid = {
            "debtorAccountId": "D1",
            "creditorIban": "FR7630006000011234567890189",
            "amount": {"value": "10.00", "currency": "EUR"},
        }
        self.assertTrue(validator.is_valid(valid))
        self.assertFalse(validator.is_valid({**valid, "other": "x"}))
        self.assertFalse(validator.is_valid({**valid, "amount": {"value": "0", "currency": "EUR"}}))
        self.assertFalse(validator.is_valid({**valid, "amount": {"value": "10.123", "currency": "EUR"}}))

    def test_success_and_problem_responses_match_contract(self):
        payment = {
            "paymentId": "abc", "status": "ACCEPTED",
            "amount": {"value": "10.00", "currency": "EUR"},
        }
        jsonschema.validate(payment, schema("Payment"))
        problem = {"title": "Not found", "status": 404, "code": "payment_not_found"}
        jsonschema.validate(problem, schema("Problem"))
        responses = DOC["paths"]["/payments"]["post"]["responses"]
        for code in ["201", "400", "401", "403", "409", "413", "422", "429"]:
            self.assertIn(code, responses)


if __name__ == "__main__":
    unittest.main()
