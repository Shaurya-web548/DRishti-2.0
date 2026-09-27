import pytest

from validation import (ValidationError, is_valid_scan_id, parse_age,
                        validate_patient, validate_scenario)


class TestAge:
    def test_blank_age_is_allowed(self):
        assert parse_age("") == "-"
        assert parse_age(None) == "-"

    def test_valid_ages_pass_through(self):
        assert parse_age("0") == "0"
        assert parse_age("55") == "55"
        assert parse_age(" 120 ") == "120"

    @pytest.mark.parametrize("raw", ["-1", "-55", "-0001"])
    def test_negative_age_is_rejected(self, raw):
        with pytest.raises(ValidationError, match="cannot be negative"):
            parse_age(raw)

    def test_age_above_limit_is_rejected(self):
        with pytest.raises(ValidationError, match="120 or less"):
            parse_age("121")

    @pytest.mark.parametrize("raw", ["abc", "4.5", "1e2", "12 years"])
    def test_non_integer_age_is_rejected(self, raw):
        with pytest.raises(ValidationError, match="whole number"):
            parse_age(raw)


class TestPatient:
    def test_long_name_is_rejected(self):
        with pytest.raises(ValidationError):
            validate_patient({"name": "x" * 81})

    def test_defaults_to_dash(self):
        assert validate_patient({}) == {"name": "-", "age": "-", "location": "-"}


class TestScenario:
    def test_empty_payload_means_baseline(self):
        assert validate_scenario(None) == {}
        assert validate_scenario({}) == {}

    def test_whole_numbers_are_rounded(self):
        assert validate_scenario({"sites": 10.0}) == {"sites": 10}

    def test_unknown_key_is_rejected(self):
        with pytest.raises(ValidationError, match="Unknown parameter"):
            validate_scenario({"rm": 1})

    @pytest.mark.parametrize("value", [-5, 0, 5_000_000])
    def test_out_of_range_is_rejected(self, value):
        with pytest.raises(ValidationError, match="between"):
            validate_scenario({"annualPatients": value})

    @pytest.mark.parametrize("value", ["100", True, None, float("nan"), float("inf")])
    def test_non_numbers_are_rejected(self, value):
        with pytest.raises(ValidationError):
            validate_scenario({"workers": value})

    def test_non_object_is_rejected(self):
        with pytest.raises(ValidationError):
            validate_scenario([1, 2])


class TestScanId:
    def test_generated_ids_are_valid(self):
        assert is_valid_scan_id("0123456789ab")

    @pytest.mark.parametrize("bad", ["..", "../etc", "ABCDEF123456", "abc", ""])
    def test_anything_else_is_invalid(self, bad):
        assert not is_valid_scan_id(bad)
