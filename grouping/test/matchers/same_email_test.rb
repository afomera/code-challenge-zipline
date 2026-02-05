require_relative "../test_helper"
require "matchers/same_email"

class SameEmailTest < Minitest::Test
  def test_basic_grouping
    headers = %w[Name Email]
    rows = [
      ["Alice", "alice@example.com"],
      ["Bob", "bob@example.com"],
      ["Alice2", "alice@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[2]
    refute_equal ids[0], ids[1]
  end

  def test_no_matches
    headers = %w[Name Email]
    rows = [
      ["Alice", "alice@example.com"],
      ["Bob", "bob@example.com"],
      ["Charlie", "charlie@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal [1, 2, 3], ids
  end

  def test_blank_emails_do_not_match
    headers = %w[Name Email]
    rows = [
      ["Alice", ""],
      ["Bob", ""],
      ["Charlie", nil]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal 3, ids.uniq.length
  end

  def test_cross_column_matching
    headers = %w[Name Email1 Email2]
    rows = [
      ["Alice", "alice@example.com", ""],
      ["Bob", "", "alice@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_case_insensitive
    headers = %w[Name Email]
    rows = [
      ["Alice", "Alice@Example.COM"],
      ["Alice2", "alice@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_transitive_via_shared_row
    headers = %w[Name Email1 Email2]
    rows = [
      ["Alice", "a@x.com", ""],
      ["Bridge", "a@x.com", "b@x.com"],
      ["Bob", "b@x.com", ""]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[1]
    assert_equal ids[1], ids[2]
  end

  def test_sequential_ids_start_at_1
    headers = %w[Name Email]
    rows = [
      ["Alice", "alice@example.com"],
      ["Bob", "bob@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal 1, ids[0]
    assert_equal 2, ids[1]
  end

  def test_whitespace_trimmed
    headers = %w[Name Email]
    rows = [
      ["Alice", " alice@example.com "],
      ["Alice2", "alice@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[1]
  end

  # --- Sanitization: invalid emails are skipped ---

  def test_no_at_sign_is_skipped
    headers = %w[Name Email]
    rows = [
      ["Alice", "notanemail"],
      ["Bob", "notanemail"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    # Both values are invalid emails, so they're skipped — rows stay separate
    assert_equal 2, ids.uniq.length
  end

  def test_multiple_at_signs_skipped
    headers = %w[Name Email]
    rows = [
      ["Alice", "bad@@example.com"],
      ["Bob", "bad@@example.com"]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal 2, ids.uniq.length
  end

  def test_extremely_long_email_skipped
    headers = %w[Name Email]
    long_email = "a" * 250 + "@example.com"
    rows = [
      ["Alice", long_email],
      ["Bob", long_email]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    # Over 254 chars => skipped, rows stay separate
    assert_equal 2, ids.uniq.length
  end

  def test_valid_long_email_still_matches
    headers = %w[Name Email]
    email = "a" * 240 + "@example.com" # 252 chars, under limit
    rows = [
      ["Alice", email],
      ["Bob", email]
    ]
    ids = group_rows(Matchers::SameEmail, rows, headers)
    assert_equal ids[0], ids[1]
  end
end
