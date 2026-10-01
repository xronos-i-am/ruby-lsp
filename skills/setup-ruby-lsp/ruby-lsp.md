# Language server: the `LSP` tool

`ruby-lsp` serves this repository, and symbol navigation goes through the `LSP` tool rather than
through text search. Below is only what you would not expect from the server.

## An empty answer on the first call means the index is not built yet

The first `findReferences` or `workspaceSymbol` of a session answers with an empty list where a
minute later it returns dozens of references. An empty answer is therefore rechecked by a repeat, not
explained by the position. A "not found" on the repeat means the symbol is not in the index — not that
it is absent from the code, and not that the question was wrong.

## The index holds the code under the workspace root, and nothing else

The server indexes the directory the session started in. Code outside it, and code in gems, is not
there: a question about it comes back empty exactly as if the symbol did not exist. A list of
references collected this way can be complete only for what the root covers, which is worth saying
out loud when reporting one.

An addon adds part of what the gems would have given — `ruby-lsp` has them per framework, and one may
be active here. So look at which addons are installed before concluding anything from an empty answer:
what resolves and what does not depends on them.

## Constants built at runtime are missing, and the miss looks like an answer

Metaprogramming that defines constants when the code runs leaves nothing for the server to index: by a
class name it returns only the constants written by hand in that file. A position request on such a
constant does not say "not found" either — it lands on the first line of the class, which looks like an
answer and is not. For the set of values, go to the declaration that generates them.

## `hover` returns no body

On a call site you get the signature and the range of the definition, such as `L187,5-194,8`. The
comment above the definition is not in the answer, so the "why" is read from the file.

## `workspaceSymbol` matches loosely

A query made of a single class name comes back with a dozen and a half symbols, including unrelated
methods and namespaces. The list is read as candidates, not as an answer.

## This repository's own blind spots

<!-- Empty on purpose, and correct that way until somebody meets one. Everything above is true of the
     server in any project; this section is for what is true of this one — the kind of thing that only
     shows up in use, such as a file reachable through more than one path, a directory outside the
     workspace root, or a gem that builds its constants at runtime. Write one down when you run into
     it, together with the call that showed it; don't go hunting for them. -->
