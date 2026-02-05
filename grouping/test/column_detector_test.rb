require_relative "test_helper"
require "column_detector"

class ColumnDetectorTest < Minitest::Test
  def test_single_phone_column
    headers = %w[FirstName LastName Phone Email Zip]
    assert_equal [2], ColumnDetector.phone_columns(headers)
  end

  def test_multiple_phone_columns
    headers = %w[FirstName LastName Phone1 Phone2 Email1 Email2 Zip]
    assert_equal [2, 3], ColumnDetector.phone_columns(headers)
  end

  def test_single_email_column
    headers = %w[FirstName LastName Phone Email Zip]
    assert_equal [3], ColumnDetector.email_columns(headers)
  end

  def test_multiple_email_columns
    headers = %w[FirstName LastName Phone1 Phone2 Email1 Email2 Zip]
    assert_equal [4, 5], ColumnDetector.email_columns(headers)
  end

  def test_no_phone_columns
    headers = %w[FirstName LastName Email Zip]
    assert_equal [], ColumnDetector.phone_columns(headers)
  end

  def test_no_email_columns
    headers = %w[FirstName LastName Phone Zip]
    assert_equal [], ColumnDetector.email_columns(headers)
  end

  def test_case_insensitive_phone
    headers = %w[firstName lastName PHONE email zip]
    assert_equal [2], ColumnDetector.phone_columns(headers)
  end

  def test_case_insensitive_email
    headers = %w[firstName lastName phone EMAIL zip]
    assert_equal [3], ColumnDetector.email_columns(headers)
  end

  def test_substring_match
    headers = %w[HomePhone WorkEmail]
    assert_equal [0], ColumnDetector.phone_columns(headers)
    assert_equal [1], ColumnDetector.email_columns(headers)
  end
end
