# AGENTS.md

This repository recreates GNU `tsort`, the topological sort of a partial
order, in the Loup programming language, as part of the loup-cmd series of
example applications. The program is `host.dual` Loup built as a native
executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── LICENSE                      # MIT license (copyright Code Craft AI LLC)
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses (0, 1)
│   ├── cli/
│   │   ├── args.loup            # class Options, class ArgError, parse_args(): --help, --version, -l, -q
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_tsort, exit status
│   └── commands/
│       ├── tsort.loup           # run_tsort(), relations_from(), quote_name(), reading the input
│       ├── tokens.loup          # class Tokens implements Iterator[string]
│       ├── graph.loup           # class Graph[T]: labels, waiting counts, successor lists
│       ├── order.loup           # enum Event, walk_order(), gnu_order[T](), gnu_loop[T]()
│       └── cycles.loup          # components() (Tarjan), longest_cycle() for -l
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── fixtures/                # sample inputs (a build graph, loops)
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/tsort/                 # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="tests/fixtures/build.txt"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter loop"` | tests whose name contains `loop` |
| Run one test file | `make test TEST_ARGS="--file tests/order_test.loup"` | |
| Build | `make build` | native binary at `build/tsort` |
| Run the binary | `build/tsort tests/fixtures/loops.txt` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/tsort`: output, messages and statuses |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/tsort --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

The e2e expectations are GNU tsort 9.5's output with `LC_ALL=C` (installed
on some machines as `gnutsort`), except the help and version text and the
BSD options. Compare new cases with GNU before adding them, with
`< /dev/null` or a given input.

## Making a change

1. Update the spec in `specs/tsort/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/tsort/tasks.md`.

Keep behaviour in functions that return values: `gnu_order` returns the
events (items to write, loops to report) and only `run_tsort` prints them,
so `tests/order_test.loup` can compare whole runs as strings.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from commands.graph import (Graph);`. Tests import them the same way. Do
  not use relative imports (`from .args import ...`): the self-hosted `loup
  run` on Linux x86-64 fails on them.
- Changing GNU's order is a bug: the successor lists put the newest pair
  first, the walk is byte order (`walk_order`), the ready queue is first in
  first out, and the loop search keeps GNU's chain rules. Compare with GNU
  tsort on new inputs.
- Drive `Tokens` by calling `next()` in a loop: natively, `for (x in ...)`
  over a user-defined iterator runs zero times in Loup 1.26.0.
- Generic code must not compare `T` values or return `Option[T]`: both go
  wrong in the Loup 1.26.0 native build. Labels are compared outside the
  generic code (`walk_order` works on `Graph[string]`).
- Records that cross modules are classes, not structs: native builds corrupt
  struct values that cross module boundaries when another type shares field
  names.
- Check `exists` (and `test -r`) before `readText`: the native runtime
  cannot catch the error a missing or unreadable file raises.
- `system.collections` dict helpers (`toEntries`, `groupBy`, ...) crash or
  do not build natively; loop over `d.keys()` instead.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
