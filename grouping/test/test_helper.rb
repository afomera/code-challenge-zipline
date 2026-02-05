require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Helper to bridge old batch API to new streaming API for tests.
# Instead of Matchers::SameEmail.group(rows, headers), use:
#   group_rows(Matchers::SameEmail, rows, headers)
def group_rows(matcher_class, rows, headers)
  matcher = matcher_class.new(headers)
  rows.each_with_index { |row, i| matcher.process_row(row, i) }
  matcher.person_ids
end
