defmodule ExchemaStreamData.MixProject do
  use Mix.Project

  def project do
    [
      app: :exchema_stream_data,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exchema, "~> 0.4.0"},
      {:stream_data, "~> 0.4.2"}
    ]
  end
end
