# ExchemaStreamData

This helps you generate test data for property testing if you are using `stream_data` and `exchema`

You would do something like

```elixir
  property "types are valid" do
    check all value <- ExchemaStreamData.gen(MyExchemaType) do
      assert Exchema.is?(value, MyExchemaType)
    end
  end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exchema_stream_data` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exchema_stream_data, "~> 0.1.0", only: [:test]}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exchema_stream_data](https://hexdocs.pm/exchema_stream_data).

## TODO

- [X] Generate for all exchema base types
- [ ] Allow to override generation for a specific type (useful for custom types or types with a lot of refinements)