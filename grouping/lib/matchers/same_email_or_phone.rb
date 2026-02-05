# frozen_string_literal: true

require_relative "../union_find"
require_relative "../column_detector"
require_relative "../phone_normalizer"
require_relative "base"

module Matchers
  # Groups CSV rows that share an email address OR a phone number.
  #
  # This is the most powerful matcher because Union-Find gives us
  # transitive closure for free. Example:
  #   - Row A and Row B share a phone number  => A and B are grouped
  #   - Row B and Row C share an email address => B and C are grouped
  #   - Therefore A, B, and C are all the same person (even though
  #     A and C share nothing directly)
  #
  # We feed both email and phone values into the SAME Union-Find
  # instance. The "seen" hash keys are prefixed with "email:" or "phone:"
  # so that an email "5551234567@example.com" can't accidentally collide
  # with a phone number "5551234567".
  class SameEmailOrPhone
    include Base

    def initialize(headers)
      @email_cols = ColumnDetector.email_columns(headers)
      @phone_cols = ColumnDetector.phone_columns(headers)
      @uf = nil
      @row_count = 0

      # Shared lookup: prefixed keys ensure emails and phones don't collide.
      # e.g. "email:alice@home.com" vs "phone:5551234567"
      @seen = {}
    end

    # Process a single row during the streaming pass.
    def process_row(row_fields, index)
      @row_count = index + 1
      @uf ||= UnionFind.new(0)
      ensure_capacity(index)

      # Process email columns
      @email_cols.each do |col|
        val = row_fields[col]
        next if val.nil?

        # Cache strip to avoid calling it twice
        stripped = val.strip
        next if stripped.empty?

        normalized = stripped.downcase

        # Skip values that are too long or not valid emails
        next if normalized.length > Matchers::MAX_FIELD_LENGTH
        next unless valid_email?(normalized)

        key = "email:#{normalized}"
        if @seen.key?(key)
          @uf.union(index, @seen[key])
        else
          @seen[key] = index
        end
      end

      # Process phone columns — same Union-Find instance, so a row
      # linked by phone and another linked by email will transitively
      # merge if they share a common row.
      @phone_cols.each do |col|
        normalized = PhoneNormalizer.normalize(row_fields[col])
        next if normalized.nil?

        key = "phone:#{normalized}"
        if @seen.key?(key)
          @uf.union(index, @seen[key])
        else
          @seen[key] = index
        end
      end
    end
  end
end
