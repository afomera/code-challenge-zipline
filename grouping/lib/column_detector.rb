# frozen_string_literal: true

# Figures out which CSV columns contain phone numbers or email addresses
# by pattern-matching on the header names. This way the matchers don't
# need to hardcode column positions — they work with any CSV that has
# headers like "Phone", "Phone1", "Email", "WorkEmail", etc.
#
# Returns arrays of column indices (0-based) so matchers can loop over
# the right fields for each row.
module ColumnDetector
  # Returns indices of headers containing "phone" (case-insensitive).
  # e.g. ["Name", "Phone1", "Phone2", "Email"] => [1, 2]
  def self.phone_columns(headers)
    headers.each_index.select { |i| headers[i] =~ /phone/i }
  end

  # Returns indices of headers containing "email" (case-insensitive).
  # e.g. ["Name", "Phone", "Email1", "Email2"] => [2, 3]
  def self.email_columns(headers)
    headers.each_index.select { |i| headers[i] =~ /email/i }
  end
end
