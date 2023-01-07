defmodule Eventize.EventStore.EventStoreDB.MixProject do
  use Mix.Project

  def project do
    [
      app: :eventize_eventstore_eventstoredb,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
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
      {:eventize, path: "/home/mattias/projects/eventize"},
      {:spear, "~> 1.3"},
      {:jason, "~> 1.0"},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.29.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "/home/mattias/projects/eventize/test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
