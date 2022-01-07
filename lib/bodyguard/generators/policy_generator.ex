defmodule Bodyguard.Generators.PolicyGenerator do
  @moduledoc false

  use Bodyguard.Generator

  include_templates policy: [:module]

  def init(args) do
    case OptionParser.parse(args, switches: []) do
      {[], [module_name], []} ->
        unless String.ends_with?(module_name, "Policy") do
          IO.warn("Policy modules should have the 'Policy' suffix, e.g. '#{module_name}Policy'", [])
        end

        {:ok, %{module: String.to_atom("Elixir.#{module_name}")}}

      _ ->
        :error
    end
  end

  def run(%{module: module}) do
    content = render_policy(inspect(module))
    path = module_to_path(module)

    [%{content: content, path: path}]
  end
end
