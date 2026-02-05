require_relative "test_helper"
require "phone_normalizer"

class PhoneNormalizerTest < Minitest::Test
  def test_strips_parentheses_and_dashes
    assert_equal "5551234567", PhoneNormalizer.normalize("(555) 123-4567")
  end

  def test_strips_dots
    assert_equal "4441234567", PhoneNormalizer.normalize("444.123.4567")
  end

  def test_strips_leading_1_from_11_digits
    assert_equal "5556549873", PhoneNormalizer.normalize("15556549873")
  end

  def test_strips_leading_1_with_formatting
    assert_equal "8554047690", PhoneNormalizer.normalize("1-855-404-7690")
  end

  def test_returns_nil_for_nil
    assert_nil PhoneNormalizer.normalize(nil)
  end

  def test_returns_nil_for_empty_string
    assert_nil PhoneNormalizer.normalize("")
  end

  def test_returns_nil_for_whitespace_only
    assert_nil PhoneNormalizer.normalize("   ")
  end

  def test_plain_digits
    assert_equal "5551234567", PhoneNormalizer.normalize("5551234567")
  end

  def test_short_number_preserved
    assert_equal "1234567", PhoneNormalizer.normalize("123-4567")
  end

  def test_does_not_strip_1_from_10_digits
    assert_equal "1234567890", PhoneNormalizer.normalize("1234567890")
  end

  def test_spaces_stripped
    assert_equal "5551234567", PhoneNormalizer.normalize("555 123 4567")
  end

  # --- Length validation ---

  def test_too_short_returns_nil
    assert_nil PhoneNormalizer.normalize("12")
    assert_nil PhoneNormalizer.normalize("12345")
    assert_nil PhoneNormalizer.normalize("123456")
  end

  def test_eight_digits_returns_nil
    # 8-digit numbers are ambiguous (not standard US format)
    assert_nil PhoneNormalizer.normalize("12345678")
  end

  def test_nine_digits_returns_nil
    # 9-digit numbers look like SSNs, not phone numbers
    assert_nil PhoneNormalizer.normalize("123456789")
  end

  def test_too_long_returns_nil
    assert_nil PhoneNormalizer.normalize("1234567890123456")
  end

  def test_valid_international_15_digits
    assert_equal "123456789012345", PhoneNormalizer.normalize("123456789012345")
  end

  # --- Type safety ---

  def test_integer_input
    assert_equal "5551234567", PhoneNormalizer.normalize(5551234567)
  end

  def test_nil_input
    assert_nil PhoneNormalizer.normalize(nil)
  end
end
