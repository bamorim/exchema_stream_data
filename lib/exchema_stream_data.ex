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

  def gen(type_mod) do
    # If we have recursive type specs, I use bind here to lazily evaluate them
    bind(nil, fn _ ->
      scale(
        filter(do_gen(type_mod), &Exchema.is?(&1, type_mod)),
        # We need to reduce the scale everytime so recursive calls have a drift towards
        # Smaller structs. So for example, if we have a list of lists recursively,
        # the probability of an infinite struct reduces. I'm using `/2` right now
        # but I have no statistical proof/analyisis to prove this is the best approach
        &max(trunc(&1 / 1.5), 1)
      )
    end)
  end

  # Generate for base types
  defp do_gen(T.Atom), do: atom(:alphanumeric)
  defp do_gen(T.Boolean), do: boolean()
  defp do_gen(T.Date), do: map(gen(T.DateTime), &DateTime.to_date/1)

  defp do_gen(T.DateTime),
    do: map(integer(-62_167_219_200..253_402_300_799), &DateTime.from_unix!/1)

  defp do_gen(T.NaiveDateTime), do: map(gen(T.DateTime), &DateTime.to_naive/1)
  defp do_gen(T.Time), do: map(gen(T.DateTime), &DateTime.to_time/1)
  defp do_gen(T.String), do: string(:ascii)

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
    defp do_gen(unquote(mod)), do: unquote(body)

    defp do_gen(unquote(Module.concat(mod, Positive))),
      do: map(unquote(body), &(1 + abs(&1)))

    defp do_gen(unquote(Module.concat(mod, Negative))),
      do: map(unquote(body), &(0 - 1 - abs(&1)))

    defp do_gen(unquote(Module.concat(mod, NonNegative))),
      do: map(unquote(body), &(0 + abs(&1)))

    defp do_gen(unquote(Module.concat(mod, NonPositive))),
      do: map(unquote(body), &(0 - abs(&1)))
  end)

  # Container types
  defp do_gen({T.Struct, {mod, fields}}) do
    fields
    |> Enum.map(fn {key, type} ->
      {key, gen(type)}
    end)
    |> List.to_tuple()
    |> map(fn fields ->
      struct(mod, fields |> Tuple.to_list() |> Enum.into(%{}))
    end)
  end

  defp do_gen({T.Struct, mod}) do
    fields =
      mod.__struct__()
      |> Map.keys()
      |> List.delete(:__struct__)
      |> Enum.map(&{&1, :any})

    do_gen({T.Struct, {mod, fields}})
  end

  defp do_gen(T.Struct) do
    do_gen({T.OneOf, [T.Date, T.DateTime, T.NaiveDateTime, T.Time]})
  end

  defp do_gen(T.Tuple), do: map(gen(T.List), &List.to_tuple/1)
  defp do_gen(T.List), do: do_gen({T.List, :any})
  defp do_gen({T.List, inner}), do: list_of(gen(inner))
  defp do_gen(T.Map), do: do_gen({T.Map, {:any, :any}})
  defp do_gen({T.Map, {key, val}}), do: map(list_of({key, val}), &Enum.into(&1, %{}))

  defp do_gen({T.OneOf, types}) do
    types
    |> Enum.map(&gen/1)
    |> one_of()
  end

  defp do_gen({T.OneStructOf, types}), do: do_gen({T.OneOf, types})
  defp do_gen({T.Optional, inner}), do: one_of([nil, gen(inner)])

  # Exchema "sugar"
  defp do_gen({mod, {}}), do: do_gen(mod)
  defp do_gen({mod, {abc}}), do: do_gen({mod, abc})

  # For now, assumes any is just scalars
  defp do_gen(:any), do: do_gen({T.OneOf, @scalar_types})

  # Defaulting to super types
  defp do_gen(mod) when is_atom(mod) do
    do_ref_gen({mod, {}})
  end

  defp do_gen({mod, arg}) when not is_tuple(arg) and is_atom(mod) do
    do_ref_gen({mod, {arg}})
  end

  defp do_gen({mod, args}) when is_atom(mod) do
    do_ref_gen({mod, args})
  end

  defp do_gen({:ref, suptype, _}) do
    gen(suptype)
  end

  defp do_ref_gen(type) do
    do_gen(Exchema.Type.resolve_type(type))
  end
end
