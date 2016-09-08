defmodule Authy.Mixfile do
  use Mix.Project

  def project do
    [
      app: :authy,
      version: "0.1.1",
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
    [{:ex_doc, ">= 0.0.0", only: :dev}]
  end

  defp description do
    """
    [DEPRECATED] Please use bodyguard instead.
    """
  end

  defp package do
    [
      name: :authy,
      maintainers: ["Rockwell Schrock"],
      licenses: ["MIT"],
      links: %{
        "Bodyguard" => "https://hex.pm/packages/bodyguard",
        "GitHub" => "https://github.com/schrockwell/bodyguard"
      }
    ]
  end
end
