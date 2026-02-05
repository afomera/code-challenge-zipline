# Programming Exercise - Grouping

The goal of this exercise is to identify rows in a CSV file that
__may__ represent the __same person__ based on a provided __Matching Type__ (definition below).

The resulting program should allow us to test at least three matching types:
 - one that matches records with the same email address
 - one that matches records with the same phone number
 - one that matches records with the same email address OR the same phone number

## Guidelines

* **Please DO NOT fork this repository with your solution**
* You should use Ruby to complete this assignment.
* Only use code that you have license to use
* Your submission should be complete, including the kinds of tests, documentation and other artifacts you'd normally provide as part of a pull request or finished solution.
* Bear in mind that our interviewers will need to run your code to evaluate it, so consider dependencies carefully.
* Don't hesitate to ask us any questions to clarify the project

## Resources

### CSV Files

Three sample input files are included. All files should be successfully
processed by the resulting code.

### Matching Type

A matching type is a declaration of what logic should be used to compare the rows.

For example: A matching type named same_email might make use of an algorithm that 
matches rows based on email columns.

## Interface

At a high level, the program should take two parameters. The input file
and the matching type.

## Output

The expected output is a copy of the original CSV file with the unique
identifier of the person each row represents prepended to the row.

## Solution

### Requirements

- Ruby (tested with 2.7+, no external gems required)

### Usage

```bash
./bin/grouper <input_file> <matching_type>
```

**Matching types:**
- `same_email` — groups rows sharing any email address
- `same_phone` — groups rows sharing any phone number (with normalization)
- `same_email_or_phone` — groups rows sharing any email OR phone (transitive)

**Examples:**

```bash
./bin/grouper input1.csv same_email            # → input1_output.csv
./bin/grouper input2.csv same_email_or_phone   # → input2_output.csv
./bin/grouper input3.csv same_phone            # → input3_output.csv
```

Output is written to `<input_name>_output.csv` in the same directory as the input file.

### Running Tests

```bash
rake test
```

Or run individual test files:

```bash
ruby -Ilib -Itest test/union_find_test.rb
```

### Architecture

The solution uses a **Union-Find** (disjoint set) data structure to efficiently group rows representing the same person. See [TRADEOFFS.md](TRADEOFFS.md) for design decisions and normalization details.

```
lib/
├── grouper.rb                  # Orchestrator: parse → group → output
├── union_find.rb               # Union-Find with path compression + union by rank
├── phone_normalizer.rb         # Phone normalization (strip non-digits, leading 1)
├── column_detector.rb          # Detect phone/email columns from headers
└── matchers/
    ├── same_email.rb           # Groups rows by shared email
    ├── same_phone.rb           # Groups rows by shared phone
    └── same_email_or_phone.rb  # Groups rows by shared email OR phone
```
