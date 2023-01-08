defmodule Eventize.EventStore.EventStoreDB.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :eventize_eventstore_eventstoredb,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/DigitalCreationAb/eventize_eventstore_eventstoredb"
    ]
  end

  defp description do
    """
    A EventStoreDB implimentation of a EventStore for Eventize.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", ".formatter.exs", "README*", "LICENSE*", "test/support"],
      maintainers: ["Mattias Jakobsson"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/DigitalCreationAb/eventize_eventstore_eventstoredb"}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/eventize_eventstore_eventstoredb"
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
      {:eventize, "~> 0.1.3"},
      {:spear, "~> 1.3"},
      {:jason, "~> 1.0"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.29.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "deps/eventize/test/support"]

  defp elixirc_paths(_), do: ["lib"]
end
