require_relative "../test_helper"
require "matchers/same_email_or_phone"

class SameEmailOrPhoneTest < Minitest::Test
  def test_transitive_closure_across_field_types
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "alice@example.com"],
      ["Bob", "(555) 123-4567", "bob@example.com"],
      ["Charlie", "(999) 888-7777", "bob@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    # Alice -> Bob via phone, Bob -> Charlie via email
    assert_equal ids[0], ids[1]
    assert_equal ids[1], ids[2]
  end

  def test_no_false_transitive_links
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "alice@example.com"],
      ["Bob", "(999) 888-7777", "bob@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    refute_equal ids[0], ids[1]
  end

  def test_disjoint_fields_stay_separate
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "alice@example.com"],
      ["Bob", "(999) 888-7777", "bob@example.com"],
      ["Charlie", "(444) 555-6666", "charlie@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal 3, ids.uniq.length
  end

  def test_star_topology
    headers = %w[Name Phone Email]
    rows = [
      ["Center", "(555) 123-4567", "center@example.com"],
      ["Spoke1", "(555) 123-4567", "spoke1@example.com"],
      ["Spoke2", "(555) 123-4567", "spoke2@example.com"],
      ["Spoke3", "(999) 999-9999", "center@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal 1, ids.uniq.length
  end

  def test_empty_rows_isolated
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "", ""],
      ["Bob", "", ""],
      ["Charlie", nil, nil]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal 3, ids.uniq.length
  end

  def test_email_only_match
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "shared@example.com"],
      ["Bob", "(999) 888-7777", "shared@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_phone_only_match
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "alice@example.com"],
      ["Bob", "15551234567", "bob@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_multiple_columns
    headers = %w[Name Phone1 Phone2 Email1 Email2]
    rows = [
      ["Alice", "(555) 123-4567", "", "alice@example.com", ""],
      ["Bob", "", "(555) 123-4567", "", "bob@example.com"],
      ["Charlie", "(999) 999-9999", "", "", "bob@example.com"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    assert_equal 1, ids.uniq.length
  end

  # --- Sanitization: invalid emails are skipped but phones still match ---

  def test_invalid_email_skipped_but_phone_still_works
    headers = %w[Name Phone Email]
    rows = [
      ["Alice", "(555) 123-4567", "notanemail"],
      ["Bob", "(555) 123-4567", "notanemail"]
    ]
    ids = group_rows(Matchers::SameEmailOrPhone, rows, headers)
    # Invalid emails skipped, but phone still links them
    assert_equal ids[0], ids[1]
  end
end
