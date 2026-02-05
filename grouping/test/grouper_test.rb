require_relative "test_helper"
require "grouper"
require "csv"
require "fileutils"

class GrouperTest < Minitest::Test
  INPUT_DIR = File.expand_path("../", __dir__)

  def run_grouper(file, matching_type)
    input_path = File.join(INPUT_DIR, file)
    Grouper.run(input_path, matching_type)

    ext = File.extname(file)
    base = File.basename(file, ext)
    output_path = File.join(INPUT_DIR, "#{base}_output#{ext}")
    csv = CSV.read(output_path)
    csv
  end

  def teardown
    Dir.glob(File.join(INPUT_DIR, "*_output.csv")).each { |f| FileUtils.rm_f(f) }
  end

  # --- input1.csv (CR line endings) ---

  def test_input1_same_email
    csv = run_grouper("input1.csv", "same_email")
    assert_equal 9, csv.length # header + 8 rows
    assert_equal "PersonID", csv[0][0]

    ids = csv[1..].map { |row| row[0].to_i }
    # Row 1 (janes@home.com) and Row 6 (janes@home.com) should match
    assert_equal ids[1], ids[6]
  end

  def test_input1_same_phone
    csv = run_grouper("input1.csv", "same_phone")
    assert_equal 9, csv.length

    ids = csv[1..].map { |row| row[0].to_i }
    # Row 0: (555) 123-4567, Row 1: (555) 123-4567
    assert_equal ids[0], ids[1]
    # Row 2: 444.123.4567, Row 5: 14441234567
    assert_equal ids[2], ids[5]
  end

  def test_input1_same_email_or_phone
    csv = run_grouper("input1.csv", "same_email_or_phone")
    assert_equal 9, csv.length

    ids = csv[1..].map { |row| row[0].to_i }
    assert_equal ids[0], ids[1] # via phone
    assert_equal ids[1], ids[6] # via email janes@home.com
  end

  # --- input2.csv ---

  def test_input2_same_email
    csv = run_grouper("input2.csv", "same_email")
    assert_equal 7, csv.length # header + 6 rows

    ids = csv[1..].map { |row| row[0].to_i }
    jill_id = ids[5]
    ids[0..4].each { |id| refute_equal jill_id, id }
  end

  def test_input2_same_email_or_phone
    csv = run_grouper("input2.csv", "same_email_or_phone")
    ids = csv[1..].map { |row| row[0].to_i }

    # John, Jane, Jack, Josh should all be grouped (rows 0-4)
    assert_equal 1, ids[0..4].uniq.length
    # Jill separate
    refute_equal ids[0], ids[5]
  end

  def test_input2_same_phone
    csv = run_grouper("input2.csv", "same_phone")
    ids = csv[1..].map { |row| row[0].to_i }

    # John, Jane, Jack linked via phone
    assert_equal ids[0], ids[1]
    assert_equal ids[1], ids[2]
    # Jill separate
    refute_equal ids[0], ids[5]
  end

  # --- input3.csv (20K rows) ---

  def test_input3_same_email_completes
    csv = run_grouper("input3.csv", "same_email")
    assert_equal 20001, csv.length # header + 20000 rows
    assert_equal "PersonID", csv[0][0]
  end

  def test_input3_same_phone_completes
    csv = run_grouper("input3.csv", "same_phone")
    assert_equal 20001, csv.length
  end

  def test_input3_same_email_or_phone_completes
    csv = run_grouper("input3.csv", "same_email_or_phone")
    assert_equal 20001, csv.length
  end

  # --- Error handling ---

  def test_invalid_matcher
    assert_raises(SystemExit) do
      Grouper.run(File.join(INPUT_DIR, "input1.csv"), "invalid_matcher")
    end
  end

  def test_missing_file
    assert_raises(SystemExit) do
      Grouper.run(File.join(INPUT_DIR, "nonexistent.csv"), "same_email")
    end
  end

  # --- Output format ---

  def test_output_header_format
    csv = run_grouper("input2.csv", "same_email")
    assert_equal %w[PersonID FirstName LastName Phone1 Phone2 Email1 Email2 Zip], csv[0]
  end

  def test_output_file_created
    input_path = File.join(INPUT_DIR, "input2.csv")
    Grouper.run(input_path, "same_email")

    output_path = File.join(INPUT_DIR, "input2_output.csv")
    assert File.exist?(output_path), "Expected output file to be created at #{output_path}"
  end

  # --- Formula sanitization ---

  def test_sanitize_cell_prefixes_equals
    assert_equal "\t=SUM(A1)", Grouper.sanitize_cell("=SUM(A1)")
  end

  def test_sanitize_cell_prefixes_plus
    assert_equal "\t+1234", Grouper.sanitize_cell("+1234")
  end

  def test_sanitize_cell_prefixes_minus
    assert_equal "\t-1234", Grouper.sanitize_cell("-1234")
  end

  def test_sanitize_cell_prefixes_at
    assert_equal "\t@SUM(A1)", Grouper.sanitize_cell("@SUM(A1)")
  end

  def test_sanitize_cell_passes_normal_values
    assert_equal "hello", Grouper.sanitize_cell("hello")
    assert_equal "alice@example.com", Grouper.sanitize_cell("alice@example.com")
  end

  def test_sanitize_cell_handles_nil
    assert_equal "", Grouper.sanitize_cell(nil)
  end
end
