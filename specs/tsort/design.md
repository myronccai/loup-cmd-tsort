# Design: tsort

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the
options, handles `--help` and `--version`, and calls
`commands.tsort.run_tsort`. That reads the input, turns it into a graph,
asks `commands.order.gnu_order` for the events of GNU's algorithm (items
to write, loops to report) and prints them, so the order and the loop
reports can be tested without capturing output.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `ArgError`, `parse_args` (GNU's standard-options-only parser) |
| `source/cli/app.loup` | `run()`: parse, `--help`, `--version`, run, exit status |
| `source/commands/tokens.loup` | `class Tokens implements Iterator[string]`: the items of a text |
| `source/commands/graph.loup` | `class Graph[T]`: labelled nodes, predecessor counts, successor lists |
| `source/commands/order.loup` | `enum Event`, `walk_order` (byte order), `gnu_order` (the algorithm), `gnu_loop` (GNU's loop search) |
| `source/commands/cycles.loup` | `-l`: `components` (Tarjan), `longest_cycle` (bounded depth-first search) |
| `source/commands/tsort.loup` | reading the input, `relations_from`, `run_tsort`, file name quoting |

## Data

`Graph[T]` keeps, per node, its label, how many predecessors are still
unwritten (`waiting`) and its successors as a linked list in index arrays:
`newest[node]` is its last recorded edge, `edge_older[e]` the edge recorded
before it. New edges go in front, which gives GNU's successor order (last
pair first) and lets one edge be unlinked when a loop is broken. Pairs
are read as `(int, int)` tuples of node indexes.

## Algorithm

GNU tsort is Knuth's algorithm T (The Art of Computer Programming, 2.2.3)
with a search tree of the items:

1. **Walk order.** GNU visits items by walking its search tree, which is
   byte order. `walk_order` gets the same order by draining a
   `PriorityQueue` of node indexes compared by label.
2. **Ready queue.** Each round adds, in walk order, the unwritten items
   with no unwritten predecessor; writing an item releases its successors,
   and those that become free join the queue. GNU's queue is first in,
   first out: here it is a `PriorityQueue` of tickets issued in the order
   items become ready. The written items are an `OrderedSet` (in output
   order, and the test for "already written").
3. **Loops.** When items remain, GNU walks the items again, building a
   chain backwards from the first item still waiting through any item that
   has the chain's head as a successor; once an item already in the chain
   is met, the chain from the head back to that item is the loop. It is
   reported, the edge that closed it is removed, and the rounds go on. The
   walk is repeated until a loop is found. The port keeps GNU's details
   (`qlink` links, the first item's empty link) so that the same loop is
   reported; labelled loops leave the walk (`break walk`) or move to the
   next item (`continue walk`) from inside the successor scan.

4. **`-l`.** Tarjan's algorithm finds the strongly connected components
   of the waiting items; the first item in walk order whose component has
   two or more items lies on a loop. A depth-first search inside that
   component, with an explicit stack of edge cursors, keeps the longest
   simple cycle back to it; it stops after 100,000 path extensions.

## Differences from GNU tsort

- `-l` and `-q` come from BSD tsort.

- File names in messages are quoted like GNU's shell quoting for the usual
  cases (`'my file'`, `"it's"`, `'a:b'`); names with bytes outside ASCII
  are single-quoted as they are, where GNU in the C locale writes `$'\303'`
  escapes.
- `--version` prints one line and `--help` a shorter text.
- All input is read into memory first.

## Error handling

Problems with the input are reported as GNU does and give status 1. An
exception that escapes (a bug) is reported as `tsort: MESSAGE` with status
1.

## Testing

- `tests/graph_test.loup`: the generic graph with string and int labels.
- `tests/order_test.loup`: GNU's order and loop reports on known inputs.
- `tests/cycles_test.loup`: components and the longest cycle.
- `tests/tokens_test.loup`, `tests/tsort_test.loup`: items, pairs, quoting.
- `tests/args_test.loup`, `tests/app_test.loup`: options and statuses.
- `tests/e2e.sh`: the native binary against GNU tsort 9.5's output.
