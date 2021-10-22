defmodule Bodyguard.Mixfile do
  use Mix.Project

  @source_url "https://github.com/schrockwell/bodyguard"
  @version "2.4.2"

  def project do
    [
      app: :bodyguard,
      version: @version,
      elixir: "~> 1.3",
      name: "Bodyguard",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [env: [default_error: :unauthorized]]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
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
      description: description(),
      maintainers: ["Rockwell Schrock", "Ben Cates"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/bodyguard/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
