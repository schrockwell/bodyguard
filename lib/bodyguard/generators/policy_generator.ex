defmodule Bodyguard.Generators.PolicyGenerator do
  @moduledoc false

  use Bodyguard.Generator

  include_templates(policy: [:policy])

  def init(args) do
    with {parsed, [policy_name], []} <- OptionParser.parse(args, strict: [app: :string]),
         :ok <- ensure_destination_app(parsed) do
      {:ok, %{policy: String.to_atom("Elixir.#{policy_name}"), switches: parsed}}
    end
  end

  def run(%{policy: policy, switches: switches}) do
    content = render_policy(inspect(policy))
    path = module_to_path(switches[:app], policy)

    [%{content: content, path: path}]
  end
end
