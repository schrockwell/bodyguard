defmodule Bodyguard.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bodyguard,
      version: "2.4.1",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),

      # Docs
      name: "Bodyguard",
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  def application do
    [env: [default_error: :unauthorized]]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Bodyguard is a simple, flexibile authorization library with a focus
    on Phoenix 1.3+ apps.
    """
  end

  defp package do
    [
      name: :bodyguard,
      maintainers: ["Rockwell Schrock", "Ben Cates"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/schrockwell/bodyguard"
      }
    ]
  end
end
