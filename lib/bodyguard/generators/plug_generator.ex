defmodule Bodyguard.Generators.PlugGenerator do
  @moduledoc false

  use Bodyguard.Generator

  include_templates(plug: [:plug, :switches])

  @default_switches [
    app: nil,
    phx: true
  ]

  def init(args) do
    with {:ok, switches, [plug_name]} <- parse_switches(args, [app: :string, phx: :boolean], @default_switches) do
      {:ok, %{plug: String.to_atom("Elixir.#{plug_name}"), switches: switches}}
    end
  end

  def run(%{plug: plug, switches: switches}) do
    content = render_plug(inspect(plug), switches)
    path = module_to_path(switches[:app], plug)

    [%{content: content, path: path}]
  end
end
