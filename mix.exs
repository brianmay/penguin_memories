defmodule PenguinMemories.MixProject do
  use Mix.Project

  def project do
    [
      app: :penguin_memories,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_options: [warnings_as_errors: true],
      dialyzer: dialyzer(),
      compilers: [:yecc, :leex] ++ Mix.compilers()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {PenguinMemories.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.9"},
      {:phoenix_html, "~> 4.2.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:phoenix_view, "~> 2.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.3.0"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {:ecto_psql_extras, "~> 0.2"},
      {:postgrex, ">= 0.0.0"},
      {:geo_postgis, "~> 3.7"},
      {:geocalc, "~> 0.8"},
      {:floki, ">= 0.0.0", only: :test},
      {:phoenix_live_reload, "~> 1.6.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:mox, "~> 1.2.0", only: :test},
      {:paginator, "~> 1.2.0"},
      {:earmark, "~> 1.4.10"},
      {:mogrify, "~> 0.9.3"},
      {:thumbnex, "~> 0.5.0"},
      {:temp, "~> 0.4"},
      {:timex, "~> 3.5"},
      {:libcluster, "~> 3.3"},
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:assertions, "~> 0.10", only: [:dev, :test], runtime: false},
      {:plugoid, "~> 0.6.0"},
      {:replug, "~> 0.1.0"},
      {:tz, "~> 0.28.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: "dialyzer.ignore-warnings",
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit]
    ]
  end
end
