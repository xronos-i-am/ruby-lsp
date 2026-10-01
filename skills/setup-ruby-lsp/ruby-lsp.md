# Language server: the `LSP` tool

`ruby-lsp` serves this repository, and symbol navigation goes through the `LSP` tool rather than
through text search. Below is only what you would not expect from the server.

## An empty answer on the first call means the index is not built yet

The first `findReferences` or `workspaceSymbol` of a session answers with an empty list where a
minute later it returns dozens of references. An empty answer is therefore rechecked by a repeat,
not explained by the position. A "not found" on the repeat means the symbol is not in the index — not
that it is absent from the code, and not that the question was wrong.

## The server knows only this repository's code

Gems are not indexed and no framework addon is wired in, so everything a library defines for you
resolves to nothing: an ActiveRecord `where`, an `update!`, a scope. Constants that a gem builds at
runtime disappear the same way — by a class name the server returns only the constants written by
hand in that file.

For framework dynamics go to the generated schema dump and to the class itself; for a set of values
go to the declaration that generates them.

## `hover` returns no body

On a call site you get the signature and the range of the definition, such as `L187,5-194,8`. The
comment above the definition is not in the answer, so the "why" is read from the file.

## `workspaceSymbol` matches loosely

A query made of a single class name comes back with a dozen and a half symbols, including unrelated
methods and namespaces. The list is read as candidates, not as an answer.

## One file answers with several paths when it is reachable through more than one

Where code is shared by symlink, the server sees the same file through every path: one definition
comes back as several results, and two references to a method turn into twice as many. Those are
several names of one inode, not several copies — the count is read divided by the number of paths,
and the edit goes to the real file.

## This repository's own blind spots

<!-- Written by the setup-ruby-lsp skill as a seed. Check every claim above against this repository
     and keep here what is true only for it: which gems build constants at runtime, which code is
     reachable through symlinks, where the generated schema lives, which directories the server does
     not see at all. A claim that was not checked against a live LSP call does not belong here. -->
