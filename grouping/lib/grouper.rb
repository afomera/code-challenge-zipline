# frozen_string_literal: true

require "csv"
require_relative "matchers/same_email"
require_relative "matchers/same_phone"
require_relative "matchers/same_email_or_phone"

# Top-level orchestrator that ties everything together using two-pass streaming:
#
#   Pass 1: Stream the CSV row-by-row, feeding each row to the matcher.
#           Only the Union-Find structure and the "seen" hash live in memory —
#           the actual row data is NOT stored. This keeps memory usage low
#           even for million-row files.
#
#   Pass 2: Stream the CSV again, writing each row to the output file with
#           its PersonID prepended. Formula-dangerous cells are sanitized.
#
# Usage: Grouper.run("input.csv", "same_email")
# Output: writes "input_output.csv" in the same directory
module Grouper
  # Maps the CLI matching_type argument to the class that implements it.
  MATCHERS = {
    "same_email" => Matchers::SameEmail,
    "same_phone" => Matchers::SamePhone,
    "same_email_or_phone" => Matchers::SameEmailOrPhone
  }.freeze

  # Characters that trigger formula interpretation in Excel/Google Sheets.
  # We prefix these with a tab character to neutralize them.
  FORMULA_CHARS = /\A[=+\-@]/

  def self.run(file, matching_type)
    unless file && File.exist?(file)
      $stderr.puts "Error: File '#{file}' not found."
      exit 1
    end

    matcher_class = MATCHERS[matching_type]
    unless matcher_class
      $stderr.puts "Error: Unknown matching type '#{matching_type}'. Valid types: #{MATCHERS.keys.join(', ')}"
      exit 1
    end

    # --- Pass 1: Stream rows through the matcher to build groups ---
    # Only the matcher's internal state (Union-Find + seen hash) stays in
    # memory. Row data is discarded after each iteration.
    headers = nil
    matcher = nil
    row_index = 0

    # row_sep: :auto handles \n, \r\n, and \r line endings automatically.
    # This matters because input1.csv uses bare \r (old Mac-style).
    CSV.foreach(file, headers: true, row_sep: :auto) do |row|
      if headers.nil?
        headers = row.headers
        matcher = matcher_class.new(headers)
      end
      matcher.process_row(row.fields, row_index)
      row_index += 1
    end

    # Handle empty CSV (headers only, no data rows)
    if row_index == 0
      headers ||= CSV.open(file, headers: true, row_sep: :auto, &:headers)
      output_file = generate_output_path(file)
      CSV.open(output_file, "w") { |out| out << ["PersonID"] + headers }
      $stderr.puts "Wrote 0 rows to #{output_file}"
      return
    end

    person_ids = matcher.person_ids

    # --- Pass 2: Stream rows again, writing output with PersonIDs ---
    output_file = generate_output_path(file)
    row_index = 0

    CSV.open(output_file, "w") do |out|
      out << ["PersonID"] + headers

      CSV.foreach(file, headers: true, row_sep: :auto) do |row|
        # Sanitize each cell to prevent formula injection in spreadsheets.
        # Splat avoids allocating a temporary concatenated array.
        out << [person_ids[row_index], *row.fields.map { |v| sanitize_cell(v) }]
        row_index += 1
      end
    end

    $stderr.puts "Wrote #{row_index} rows to #{output_file}"
  end

  # Prevents CSV formula injection by prefixing dangerous values with a
  # tab character. Excel/Sheets treat \t-prefixed cells as plain text,
  # and the tab is invisible when the spreadsheet renders.
  def self.sanitize_cell(value)
    val = value.to_s
    val.match?(FORMULA_CHARS) ? "\t#{val}" : val
  end

  # Derives output filename from input: "input2.csv" => "input2_output.csv"
  def self.generate_output_path(input_path)
    dir = File.dirname(input_path)
    ext = File.extname(input_path)
    base = File.basename(input_path, ext)
    File.join(dir, "#{base}_output#{ext}")
  end

  private_class_method :generate_output_path
end
