defmodule ExchemaStreamDataTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Exchema.Types, as: T
  import StreamData

  property "it generates valid types" do
    check all type_mod <- types(),
              value <- ExchemaStreamData.gen(type_mod),
              max_run_time: 2000,
              max_runs: 1000 do
      assert Exchema.is?(value, type_mod)
    end
  end

  # I'm testing this separately because it obviously can get more complicated
  # So I run with less runs
  property "it generates valid recursive types" do
    check all type_mod <- recursive_types(),
              value <- ExchemaStreamData.gen(type_mod),
              max_run_time: 2000,
              max_runs: 100 do
      assert Exchema.is?(value, type_mod)
    end
  end

  def types do
    one_of([
      T.Atom,
      T.Boolean,
      T.Date,
      T.DateTime,
      T.Float,
      T.Float.Negative,
      T.Float.NonNegative,
      T.Float.NonPositive,
      T.Float.Positive,
      T.Integer,
      T.Integer.Negative,
      T.Integer.NonNegative,
      T.Integer.NonPositive,
      T.Integer.Positive,
      T.NaiveDateTime,
      T.Number,
      T.Number.Negative,
      T.Number.NonNegative,
      T.Number.NonPositive,
      T.Number.Positive,
      T.String,
      T.Time,
      T.Tuple,
      T.List,
      T.Map,
      {T.OneOf, constant([:any])},
      {T.Optional, :any},
      T.Struct,
      SimpleStruct,
      EvenInt
    ])
  end

  defp recursive_types do
    one_of([
      {T.OneStructOf, constant([SimpleStruct, RecursiveStruct])},
      Recursive,
      RecursiveStruct
    ])
  end
end
