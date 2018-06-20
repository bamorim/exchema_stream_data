defmodule ExchemaStreamData do
  @moduledoc """
  Generates StreamData generators automatically for your Exchema Types
  """

  import StreamData
  alias Exchema.Types, as: T

  @scalar_types [
    T.Atom,
    T.Boolean,
    T.Date,
    T.DateTime,
    T.NaiveDateTime,
    T.Time,
    T.String,
    T.Number
  ]

  def gen(type_mod, overrides \\ fn _, o -> o end) do
    type_mod
    |> generator_for(overrides)
    |> filter(&Exchema.is?(&1, type_mod))
  end

  def generator_for(type, overrides) do
    overrides.(type, do_generator_for(type, overrides))
  end

  # Generate for base types
  defp do_generator_for(T.Atom, _), do: atom(:alphanumeric)
  defp do_generator_for(T.Boolean, _), do: boolean()
  defp do_generator_for(T.String, _), do: string(:ascii)

  # Date/Time Types
  defp do_generator_for(T.DateTime, _),
    do: map(integer(-62_167_219_200..253_402_300_799), &DateTime.from_unix!/1)
    
  defp do_generator_for(T.Date, overrides),
    do: map(gen(T.DateTime, overrides), &DateTime.to_date/1)

  defp do_generator_for(T.NaiveDateTime, overrides),
    do: map(gen(T.DateTime, overrides), &DateTime.to_naive/1)

  defp do_generator_for(T.Time, overrides),
    do: map(gen(T.DateTime, overrides), &DateTime.to_time/1)

  # Numeric types
  %{
    T.Integer =>
      quote do
        integer()
      end,
    T.Float =>
      quote do
        float()
      end,
    T.Number =>
      quote do
        one_of([integer(), float()])
      end
  }
  |> Map.to_list()
  |> Enum.map(fn {mod, body} ->
    defp do_generator_for(unquote(mod), _), do: unquote(body)

    defp do_generator_for(unquote(Module.concat(mod, Positive)), _),
      do: map(unquote(body), &(1 + abs(&1)))

    defp do_generator_for(unquote(Module.concat(mod, Negative)), _),
      do: map(unquote(body), &(0 - 1 - abs(&1)))

    defp do_generator_for(unquote(Module.concat(mod, NonNegative)), _),
      do: map(unquote(body), &(0 + abs(&1)))

    defp do_generator_for(unquote(Module.concat(mod, NonPositive)), _),
      do: map(unquote(body), &(0 - abs(&1)))
  end)

  # Container Types Aliases
  defp do_generator_for(T.Struct, overrides),
    do: generator_for({T.OneOf, [T.Date, T.DateTime, T.NaiveDateTime, T.Time]}, overrides)

  defp do_generator_for(T.Tuple, overrides),
    do: map(generator_for(T.List, overrides), &List.to_tuple/1)
    
  defp do_generator_for(T.List, overrides), do: generator_for({T.List, :any}, overrides)
  defp do_generator_for(T.Map, overrides), do: generator_for({T.Map, {:any, :any}}, overrides)

  defp do_generator_for({T.OneStructOf, types}, overrides), do: generator_for({T.OneOf, types}, overrides)

  # Container types
  defp do_generator_for({T.Struct, {mod, fields}}, overrides) do
    fields
    |> Enum.map(fn {key, type} ->
      {key, child_gen(type, overrides)}
    end)
    |> List.to_tuple()
    |> map(fn fields ->
      struct(mod, fields |> Tuple.to_list() |> Enum.into(%{}))
    end)
  end

  defp do_generator_for({T.Struct, mod}, overrides) do
    fields =
      mod.__struct__()
      |> Map.keys()
      |> List.delete(:__struct__)
      |> Enum.map(&{&1, :any})

    generator_for({T.Struct, {mod, fields}}, overrides)
  end

  defp do_generator_for({T.List, inner}, overrides), do: list_of(child_gen(inner, overrides))
  defp do_generator_for({T.Map, {key, val}}, overrides) do
    map(
      list_of({child_gen(key, overrides), child_gen(val, overrides)}),
      &Enum.into(&1, %{})
    )
  end

  defp do_generator_for({T.OneOf, types}, overrides) do
    types
    |> Enum.map(&child_gen(&1, overrides))
    |> one_of()
  end

  defp do_generator_for({T.Optional, inner}, overrides), do: one_of([nil, child_gen(inner, overrides)])

  # Exchema "sugar"
  defp do_generator_for({mod, {}}, overrides), do: generator_for(mod, overrides)
  defp do_generator_for({mod, {abc}}, overrides), do: generator_for({mod, abc}, overrides)

  # For now, assumes any is just scalars
  defp do_generator_for(:any, overrides), do: generator_for({T.OneOf, @scalar_types}, overrides)

  # Defaulting to super types
  defp do_generator_for(mod, overrides) when is_atom(mod) do
    do_ref_gen({mod, {}}, overrides)
  end

  defp do_generator_for({mod, arg}, overrides) when not is_tuple(arg) and is_atom(mod) do
    do_ref_gen({mod, {arg}}, overrides)
  end

  defp do_generator_for({mod, args}, overrides) when is_atom(mod) do
    do_ref_gen({mod, args}, overrides)
  end

  defp do_generator_for({:ref, suptype, _}, overrides) do
    generator_for(suptype, overrides)
  end

  defp do_ref_gen(type, overrides) do
    generator_for(Exchema.Type.resolve_type(type), overrides)
  end

  # Helper methods

  defp child_gen(type, overrides) do
    # If we have recursive type specs, I use bind here to lazily evaluate them
    bind(nil, fn _ -> unscale(gen(type, overrides)) end)
  end

  defp unscale(gen) do
    # We need to reduce the scale everytime so recursive calls have a drift towards
    # Smaller structs. So for example, if we have a list of lists recursively,
    # the probability of an infinite struct reduces. I'm using `/2` right now
    # but I have no statistical proof/analyisis to prove this is the best approach
    scale(gen, &max(trunc(&1 / 2), 1))
  end
end
