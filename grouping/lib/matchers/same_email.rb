# frozen_string_literal: true

require_relative "../union_find"
require_relative "../column_detector"
require_relative "base"

module Matchers
  # Groups CSV rows that share an email address (case-insensitive).
  #
  # How it works:
  #   1. Find which columns contain emails (via ColumnDetector)
  #   2. For each row streamed in via process_row:
  #      - If we've seen this email before, union the current row with
  #        the row that first used it. This tells Union-Find they're
  #        the same person.
  #      - If it's new, remember which row first used it.
  #   3. After all rows are processed, person_ids converts Union-Find
  #      groups into sequential PersonIDs (1, 2, 3...)
  #
  # Blank/nil emails are skipped — two rows with empty emails are NOT
  # considered the same person. Values without a valid @ are also skipped.
  class SameEmail
    include Base

    def initialize(headers)
      @cols = ColumnDetector.email_columns(headers)
      @uf = nil
      @row_count = 0

      # Maps normalized email => first row index where we saw it.
      # When a second row has the same email, we union them.
      @seen = {}
    end

    # Process a single row during the streaming pass.
    # row_fields is an Array of strings (one per CSV column).
    # index is the 0-based row number.
    def process_row(row_fields, index)
      # Lazily grow the Union-Find as rows arrive (no upfront size needed)
      @row_count = index + 1
      @uf ||= UnionFind.new(0)
      ensure_capacity(index)

      @cols.each do |col|
        val = row_fields[col]
        next if val.nil?

        # Cache strip result to avoid calling it twice
        stripped = val.strip
        next if stripped.empty?

        # Downcase for case-insensitive comparison (see TRADEOFFS.md)
        normalized = stripped.downcase

        # Skip values that are too long (memory protection) or not valid emails
        next if normalized.length > Matchers::MAX_FIELD_LENGTH
        next unless valid_email?(normalized)

        if @seen.key?(normalized)
          @uf.union(index, @seen[normalized])
        else
          @seen[normalized] = index
        end
      end
    end
  end
end
