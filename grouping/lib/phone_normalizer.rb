# frozen_string_literal: true

# Normalizes phone number strings so that different formatting of the
# same number will produce the same output. This lets us compare phones
# by simple string equality after normalization.
#
# Examples:
#   "(555) 123-4567"  => "5551234567"
#   "1-855-404-7690"  => "8554047690"   (leading US country code stripped)
#   "444.123.4567"    => "4441234567"
#   ""                => nil             (blanks are skipped, never matched)
#   "12"              => nil             (too short to be a real phone number)
module PhoneNormalizer
  # Valid phone lengths after normalization:
  #   7 digits  = local number (e.g. 555-1234)
  #   10 digits = US number with area code (e.g. 555-123-4567)
  #   11-15     = international numbers
  # Anything else (too short, too long, or 8-9 digits like SSNs) is rejected.
  VALID_LENGTHS = [7, *(10..15)].freeze

  def self.normalize(value)
    # Handle non-string inputs (e.g. integers from malformed CSV data)
    value = value.to_s
    return nil if value.strip.empty?

    # Strip everything that isn't a digit: parens, dashes, dots, spaces, etc.
    digits = value.gsub(/\D/, "")
    return nil if digits.empty?

    # US phone numbers are 10 digits. If we have 11 digits and the first
    # is "1", that's the US country code prefix — strip it so that
    # "15551234567" and "5551234567" match as the same number.
    # See TRADEOFFS.md for edge cases with international numbers.
    digits = digits[1..] if digits.length == 11 && digits[0] == "1"

    # Reject numbers that aren't a plausible phone length.
    # This prevents SSN-like 9-digit strings or random short numbers
    # from being treated as phone numbers.
    return nil unless VALID_LENGTHS.include?(digits.length)

    digits
  end
end
