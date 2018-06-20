import Exchema.Notation
alias Exchema.Types, as: T

structure(SimpleStruct, a: T.Atom, b: T.Boolean, f: T.Float)
subtype(EvenInt, T.Integer, &(rem(&1, 2) == 0))
structure(RecursiveStruct, c: {T.Optional, RecursiveStruct})
subtype(Recursive, {T.List, Recursive}, [])
ExUnit.start()
