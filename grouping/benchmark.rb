#!/usr/bin/env ruby
# Benchmark script for measuring the grouper's performance.
#
# Measures three things for each file/matcher combination:
#   - Speed: wall-clock time averaged over multiple runs
#   - Allocations: number of Ruby objects created (fewer = less GC pressure)
#   - Memory: RSS (Resident Set Size) change — how much RAM the process uses
#
# Also includes a time/allocation breakdown for the largest file to show
# where the bottlenecks are (CSV parsing vs matching vs CSV writing).
#
# Usage: ruby benchmark.rb
#   (run from the grouping/ directory so it can find the input CSVs)

require "benchmark"
require "csv"
require_relative "lib/grouper"

# --- Helpers ---

# Returns the current process's RSS (Resident Set Size) in megabytes.
# RSS is the amount of physical RAM the process is actually using.
# We shell out to `ps` because Ruby's stdlib doesn't expose this directly.
def rss_mb
  `ps -o rss= -p #{$$}`.strip.to_i / 1024.0
end

# Suppresses stdout and stderr for the duration of the block. Used to
# silence the "Wrote N rows to ..." message during benchmarking so it
# doesn't pollute the output or slow things down with I/O.
def quietly
  orig_out = $stdout
  orig_err = $stderr
  devnull = File.open(File::NULL, "w")
  $stdout = devnull
  $stderr = devnull
  yield
ensure
  devnull.close
  $stdout = orig_out
  $stderr = orig_err
end

# Counts the number of Ruby object allocations during a block.
# We disable GC so that objects aren't collected mid-measurement,
# which would give us an inaccurate count.
def allocations_during
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
ensure
  GC.enable
end

# Adds commas to a number for readability: 1458048 => "1,458,048"
def format_number(n)
  n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

# --- Config ---

FILES = %w[input1.csv input2.csv input3.csv].select { |f| File.exist?(f) }
MATCHERS = %w[same_email same_phone same_email_or_phone]
WARMUP_RUNS = 2  # Let YJIT compile hot paths before measuring
BENCH_RUNS = 5   # Number of timed runs to average

puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'enabled' : 'disabled'}"
puts

# --- Per-file, per-matcher benchmarks ---

FILES.each do |file|
  row_count = 0
  CSV.foreach(file, headers: true, row_sep: :auto) { row_count += 1 }
  file_size = File.size(file)
  puts "=" * 70
  puts "#{file} (#{format_number(row_count)} rows, #{(file_size / 1024.0).round(1)} KB)"
  puts "=" * 70
  puts

  MATCHERS.each do |matcher|
    # Warmup: let YJIT optimize and caches fill before we start timing
    WARMUP_RUNS.times { quietly { Grouper.run(file, matcher) } }

    # Measure allocations (single run with GC disabled for accuracy)
    allocs = allocations_during { quietly { Grouper.run(file, matcher) } }

    # Measure memory: force GC + compaction to get a clean baseline,
    # then check RSS delta after a run
    GC.start
    GC.compact if GC.respond_to?(:compact)
    mem_before = rss_mb
    quietly { Grouper.run(file, matcher) }
    mem_after = rss_mb

    # Measure speed: multiple runs with GC between each to reduce variance.
    # Uses CLOCK_MONOTONIC (not wall clock) to avoid system clock drift.
    times = BENCH_RUNS.times.map do
      GC.start
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      quietly { Grouper.run(file, matcher) }
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    end

    avg = times.sum / times.length
    min = times.min
    max = times.max

    puts "  #{matcher}"
    puts "    Speed:       #{(avg * 1000).round(2)} ms avg  (min: #{(min * 1000).round(2)}, max: #{(max * 1000).round(2)}, runs: #{BENCH_RUNS})"
    puts "    Allocations: #{format_number(allocs)} objects"
    puts "    Memory:      #{(mem_after - mem_before).round(2)} MB delta  (RSS: #{mem_after.round(1)} MB)"
    puts
  end
end

# --- Cleanup output files ---
Dir.glob("*_output.csv").each { |f| File.delete(f) }

# --- Breakdown: where time is spent (largest file only) ---
# This helps identify whether the bottleneck is CSV parsing, the matching
# algorithm, or CSV writing — useful for knowing where to optimize.

large_file = FILES.find { |f| f.include?("3") }
if large_file
  require_relative "lib/matchers/same_email_or_phone"

  puts "=" * 70
  puts "Time breakdown for #{large_file} (same_email_or_phone)"
  puts "=" * 70
  puts
  puts "  Two-pass streaming architecture:"
  puts "    Pass 1 = CSV parse + matching (streamed together)"
  puts "    Pass 2 = CSV parse + writing  (streamed together)"
  puts

  # Phase 1: Pass 1 — stream CSV rows through the matcher.
  # This measures CSV parsing + Union-Find matching together, since
  # in the streaming model they happen in the same pass.
  headers = nil
  matcher = nil
  pass1_time = Benchmark.realtime do
    row_index = 0
    CSV.foreach(large_file, headers: true, row_sep: :auto) do |row|
      if headers.nil?
        headers = row.headers
        matcher = Matchers::SameEmailOrPhone.new(headers)
      end
      matcher.process_row(row.fields, row_index)
      row_index += 1
    end
  end
  person_ids = matcher.person_ids

  # Phase 2: Pass 2 — stream CSV again, writing output with PersonIDs.
  output_file = "#{large_file.sub('.csv', '')}_output.csv"
  pass2_time = Benchmark.realtime do
    row_index = 0
    CSV.open(output_file, "w") do |out|
      out << ["PersonID"] + headers
      CSV.foreach(large_file, headers: true, row_sep: :auto) do |row|
        out << [person_ids[row_index], *row.fields.map { |v| Grouper.sanitize_cell(v) }]
        row_index += 1
      end
    end
  end

  total = pass1_time + pass2_time
  puts "  Pass 1 (parse+match): %8.2f ms  (%4.1f%%)" % [pass1_time * 1000, pass1_time / total * 100]
  puts "  Pass 2 (parse+write): %8.2f ms  (%4.1f%%)" % [pass2_time * 1000, pass2_time / total * 100]
  puts "  Total:                %8.2f ms" % [total * 1000]

  # Allocation breakdown — shows which pass creates the most objects.
  # High allocation counts mean more GC pressure, which can cause pauses.
  puts
  pass1_allocs = allocations_during do
    m = Matchers::SameEmailOrPhone.new(headers)
    row_index = 0
    CSV.foreach(large_file, headers: true, row_sep: :auto) do |row|
      m.process_row(row.fields, row_index)
      row_index += 1
    end
  end
  pass2_allocs = allocations_during do
    row_index = 0
    CSV.open(output_file, "w") do |out|
      out << ["PersonID"] + headers
      CSV.foreach(large_file, headers: true, row_sep: :auto) do |row|
        out << [person_ids[row_index], *row.fields.map { |v| Grouper.sanitize_cell(v) }]
        row_index += 1
      end
    end
  end

  puts "  Pass 1 (parse+match): #{format_number(pass1_allocs)} allocations"
  puts "  Pass 2 (parse+write): #{format_number(pass2_allocs)} allocations"
  puts

  # Peak memory: measure RSS after a full Grouper.run to show actual peak
  GC.start
  GC.compact if GC.respond_to?(:compact)
  mem_before = rss_mb
  quietly { Grouper.run(large_file, "same_email_or_phone") }
  mem_after = rss_mb
  puts "  Peak memory delta: #{(mem_after - mem_before).round(2)} MB"
  puts

  Dir.glob("*_output.csv").each { |f| File.delete(f) }
end
