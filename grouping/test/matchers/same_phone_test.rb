require_relative "../test_helper"
require "matchers/same_phone"

class SamePhoneTest < Minitest::Test
  def test_basic_grouping
    headers = %w[Name Phone]
    rows = [
      ["Alice", "(555) 123-4567"],
      ["Bob", "(555) 987-6543"],
      ["Alice2", "555.123.4567"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal ids[0], ids[2]
    refute_equal ids[0], ids[1]
  end

  def test_leading_1_stripped
    headers = %w[Name Phone]
    rows = [
      ["Alice", "15551234567"],
      ["Alice2", "(555) 123-4567"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_no_matches
    headers = %w[Name Phone]
    rows = [
      ["Alice", "(555) 123-4567"],
      ["Bob", "(555) 987-6543"],
      ["Charlie", "(444) 123-4567"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal [1, 2, 3], ids
  end

  def test_blank_phones_do_not_match
    headers = %w[Name Phone]
    rows = [
      ["Alice", ""],
      ["Bob", ""],
      ["Charlie", nil]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal 3, ids.uniq.length
  end

  def test_cross_column_matching
    headers = %w[Name Phone1 Phone2]
    rows = [
      ["Alice", "(555) 123-4567", ""],
      ["Bob", "", "15551234567"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_formatted_with_dashes
    headers = %w[Name Phone]
    rows = [
      ["Alice", "1-855-404-7690"],
      ["Alice2", "(855) 404-7690"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal ids[0], ids[1]
  end

  def test_sequential_ids_start_at_1
    headers = %w[Name Phone]
    rows = [
      ["Alice", "(555) 123-4567"],
      ["Bob", "(555) 987-6543"]
    ]
    ids = group_rows(Matchers::SamePhone, rows, headers)
    assert_equal 1, ids[0]
    assert_equal 2, ids[1]
  end
end
