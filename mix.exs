defmodule Authy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :authy,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application, do: []

  defp deps do
    [{:plug, "~> 1.0"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    """
    Authy is a simple authorization library for Elixir and Phoenix apps.
    It imposes some naming conventions so that policy modules can be easily
    located and queried at runtime depending on the context of the authorization.
    It was inspired by the behavior and conventions of Ruby's Pundit gem.
    """
  end

  defp package do
    [
      name: :authy,
      maintainers: ["Rockwell Schrock"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/schrockwell/authy"
      }
    ]
  end
end
