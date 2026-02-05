# frozen_string_literal: true

module Matchers
  # Maximum length for a normalized value to be stored in the seen hash.
  # Prevents memory-bomb fields from inflating memory. 254 is the max
  # email length per RFC 5321.
  MAX_FIELD_LENGTH = 254

  # Shared behavior for all matchers: PersonID assignment and Union-Find
  # capacity management. Also provides email validation for email-aware
  # matchers.
  #
  # Every matcher includes this module and gets:
  #   - person_ids:      converts Union-Find groups into sequential IDs
  #   - ensure_capacity: grows the Union-Find as rows stream in
  #   - valid_email?:    minimal @ sanity check (used by SameEmail, SameEmailOrPhone)
  module Base
    # Returns an Array of PersonIDs (integers starting at 1).
    # All rows in the same Union-Find group get the same ID.
    # The first row always gets PersonID 1.
    def person_ids
      ids = Array.new(@row_count)
      next_id = 1
      root_to_id = {}

      @row_count.times do |i|
        root = @uf.find(i)
        unless root_to_id.key?(root)
          root_to_id[root] = next_id
          next_id += 1
        end
        ids[i] = root_to_id[root]
      end

      ids
    end

    private

    # Grow the Union-Find parent/rank arrays to fit the given index.
    # This supports streaming where we don't know total row count upfront.
    def ensure_capacity(index)
      @uf.grow(index + 1) if @uf.size <= index
    end

    # Minimal email sanity check: must contain exactly one @ with
    # non-empty parts on both sides. Not full RFC 5322 validation.
    def valid_email?(normalized)
      normalized.count("@") == 1 &&
        !normalized.start_with?("@") &&
        !normalized.end_with?("@")
    end
  end
end
