# Requirements: tsort

## Introduction

`tsort` reads pairs of items, each pair saying that the first item comes
before the second, and writes all the items in one order that respects
every pair: a topological sort. Build tools use it to order libraries and
tasks. This repository recreates GNU coreutils 9.5 `tsort` in Loup,
including the exact order GNU writes, how it reports and breaks loops,
and its messages and exit statuses, and adds BSD tsort's `-l` and `-q`.

## Requirements

### Requirement 1: Input

**User Story:** As a shell user, I want to give the pairs in a file or on
standard input so that tsort fits in pipelines.

#### Acceptance Criteria

1. WHEN a FILE operand is given, THE program SHALL read it; WHEN none is
   given, or it is `-`, THE program SHALL read standard input.
2. THE program SHALL split the input into items at spaces, tabs and
   newlines (other bytes, such as `\r`, belong to the items), and take the
   items two at a time as pairs.
3. WHEN a pair names the same item twice, THE program SHALL only record
   the item.
4. WHEN the input holds an odd number of items, THE program SHALL print
   `tsort: FILE: input contains an odd number of tokens` and exit with
   status 1 without writing anything else.
5. WHEN the FILE cannot be read, THE program SHALL print GNU's message
   (`No such file or directory`, `read error: Is a directory`,
   `Permission denied`) and exit with status 1.

### Requirement 2: Order

**User Story:** As a user of build scripts, I want the same order as GNU
tsort so that outputs do not change when the tool does.

#### Acceptance Criteria

1. THE program SHALL write each item once, on its own line, after every
   item that must come before it.
2. THE program SHALL start with the items that have no predecessor, in
   byte order, and then take the items in the order they become free, the
   successors of an item visited from its last pair back to its first, as
   GNU tsort does.

### Requirement 3: Loops

**User Story:** As a user, I want to see the items of a loop so that I can
fix my input, and still get an order.

#### Acceptance Criteria

1. WHEN items are left that are all part of or behind a loop, THE program
   SHALL print `tsort: FILE: input contains a loop:` on standard error,
   then one `tsort: ITEM` line for each item of one loop, found with GNU's
   search.
2. THE program SHALL then remove one pair of that loop and go on, so that
   every item is written in the end.
3. WHEN at least one loop was found, THE exit status SHALL be 1.

### Requirement 4: Command line

**User Story:** As a shell user, I want GNU's options and messages.

#### Acceptance Criteria

1. THE program SHALL accept `--help` and `--version` (and their unambiguous
   abbreviations), the first of them ending the program with status 0.
2. THE program SHALL accept BSD tsort's `-l` and `-q`, also clustered
   (`-lq`).
3. WHEN an option is unknown, THE program SHALL print getopt's message and
   `Try 'tsort --help' for more information.` and exit with status 1.
4. WHEN more than one operand is given, THE program SHALL print `tsort:
   extra operand 'X'` and the same hint and exit with status 1.
5. THE program SHALL treat every argument after `--` as an operand.

### Requirement 5: BSD options

**User Story:** As a user untangling dependencies, I want to see the whole
loop at once, or no loop reports at all.

#### Acceptance Criteria

1. WHEN `-l` is given, THE program SHALL report, for each loop, the
   longest simple cycle through the first stuck item (in byte order) that
   lies on a cycle, starting with that item and following the pairs, and
   SHALL remove the pair that closes it.
2. WHEN `-q` is given, THE program SHALL not report loops, and the exit
   status SHALL still be 1 when there was one.
