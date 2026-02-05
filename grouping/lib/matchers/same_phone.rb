# frozen_string_literal: true

require_relative "../union_find"
require_relative "../column_detector"
require_relative "../phone_normalizer"
require_relative "base"

module Matchers
  # Groups CSV rows that share a phone number after normalization.
  # Works the same way as SameEmail (see same_email.rb for a walkthrough)
  # but uses PhoneNormalizer to handle formatting differences like:
  #   "(555) 123-4567", "555.123.4567", "15551234567" => all match
  class SamePhone
    include Base

    def initialize(headers)
      @cols = ColumnDetector.phone_columns(headers)
      @uf = nil
      @row_count = 0

      # Maps normalized phone digits => first row index where we saw it
      @seen = {}
    end

    # Process a single row during the streaming pass.
    def process_row(row_fields, index)
      @row_count = index + 1
      @uf ||= UnionFind.new(0)
      ensure_capacity(index)

      @cols.each do |col|
        normalized = PhoneNormalizer.normalize(row_fields[col])
        next if normalized.nil?

        if @seen.key?(normalized)
          @uf.union(index, @seen[normalized])
        else
          @seen[normalized] = index
        end
      end
    end
  end
end
