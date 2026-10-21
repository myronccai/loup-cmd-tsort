# loup-cmd-tsort

GNU `tsort` recreated in [Loup](https://code-craft.ai/references/loup):
read pairs of items, each saying that one comes before the other, and write
all the items in one order that respects every pair, in exactly the order
GNU tsort writes them; report loops the way GNU does, break them and go on.
The BSD options `-l` (report the longest loop) and `-q` (quiet) are added.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                         # native binary: build/tsort
make ci                                            # check, unit tests, build, end-to-end tests
make run ARGS="tests/fixtures/build.txt"           # run from source with loup run
```

```text
$ head -4 tests/fixtures/build.txt
config.h main.o
config.h parse.o
config.h eval.o
lexer.c lexer.o
$ build/tsort tests/fixtures/build.txt
config.h
lexer.c
libm
parse.y
eval.o
main.o
lexer.o
parse.c
parse.o
calc
$ build/tsort tests/fixtures/loops.txt; echo "exit $?"
docs
app
tsort: tests/fixtures/loops.txt: input contains a loop:
tsort: net
tsort: tls
net
tls
tsort: tests/fixtures/loops.txt: input contains a loop:
tsort: theme
tsort: ui
tsort: widgets
theme
ui
widgets
exit 1
$ printf 'a b\nb a\nb c\nc d\nd a\n' | build/tsort -l; echo "exit $?"
tsort: -: input contains a loop:
tsort: a
tsort: b
tsort: c
tsort: d
tsort: -: input contains a loop:
tsort: a
tsort: b
a
b
c
d
exit 1
$ echo 'a b c' | build/tsort; echo "exit $?"
tsort: -: input contains an odd number of tokens
exit 1
```

The items with no predecessor come first, in byte order; after that each
item follows as soon as everything before it has been written, which is
GNU's order (the same input gives the same output as `LC_ALL=C tsort`).
When the remaining items all wait on a loop, the loop is reported on
standard error, one of its pairs is dropped, and sorting goes on, so every
item is still written once.

Options:

| Option | Meaning |
|---|---|
| `-l` | report the longest loop through the first stuck item instead of the first loop GNU's search finds (BSD tsort) |
| `-q` | do not report loops; the exit status still says there was one (BSD tsort) |
| `--help`, `--version` | print help or the version and exit (may be shortened: `--he`) |

The input is FILE, or standard input when there is no FILE or it is `-`.
Items are separated by spaces, tabs and newlines; `--` ends the options.

Exit status: `0` if the input was sorted without loops; `1` if it
contained a loop (with or without `-q`), could not be read, had an odd
number of items, or the command line was wrong.

## Differences from the original

- `-l` and `-q` come from BSD tsort; GNU tsort has no options but `--help`
  and `--version`. Without them the output and messages are GNU's.
- `-l` searches at most 100,000 path extensions per loop on very dense
  inputs, then reports the longest loop found so far.
- File names in messages are quoted like GNU's for the usual cases
  (`'my file'`, `"it's"`, `'a:b'`); a name with bytes outside ASCII is
  single-quoted as it is, where GNU in the C locale writes `$'\303\251'`
  escapes.
- `--version` prints one line and `--help` a shorter text.
- The whole input is read into memory first.
- A file that exists but cannot be read is found by asking `test -r`
  first (the native runtime cannot catch the read error); the message is
  GNU's `Permission denied`.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, exit statuses
source/cli/args.loup             # options: --help, --version, -l, -q, one operand
source/cli/usage.loup            # --help and --version text
source/cli/app.loup              # run(): parse, dispatch, exit status
source/commands/tsort.loup       # reading the input, pairs to a graph, printing
source/commands/tokens.loup      # Tokens: an iterator over the items
source/commands/graph.loup       # Graph[T]: nodes, predecessor counts, successor lists
source/commands/order.loup       # GNU's order and loop search, as a list of events
source/commands/cycles.loup      # -l: strongly connected components, longest cycle
tests/*_test.loup                # unit tests (make test)
tests/fixtures/                  # sample inputs for the tests and this README
tests/e2e.sh                     # end-to-end tests of build/tsort (make e2e)
specs/tsort/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
