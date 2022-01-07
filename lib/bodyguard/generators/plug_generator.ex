defmodule Bodyguard.Generators.PlugGenerator do
  @moduledoc false

  use Bodyguard.Generator

  include_templates(plug: [:plug])

  def init(args) do
    with {parsed, [plug_name], []} <- OptionParser.parse(args, strict: [app: :string]),
         :ok <- ensure_destination_app(parsed) do
      {:ok, %{plug: String.to_atom("Elixir.#{plug_name}"), switches: parsed}}
    end
  end

  def run(%{plug: plug, switches: switches}) do
    content = render_plug(inspect(plug))
    path = module_to_path(switches[:app], plug)

    [%{content: content, path: path}]
  end
end
