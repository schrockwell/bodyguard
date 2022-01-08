defmodule Bodyguard.Generators.PolicyGenerator do
  @moduledoc false

  use Bodyguard.Generator

  include_templates(policy: [:policy])

  def init(args) do
    with {:ok, parsed, [policy_name]} <- parse_switches(args, [app: :string]) do
      warn_name(policy_name)

      {:ok, %{policy: String.to_atom("Elixir.#{policy_name}"), switches: parsed}}
    end
  end

  def run(%{policy: policy, switches: switches}) do
    content = render_policy(inspect(policy))
    path = module_to_path(switches[:app], policy)

    [%{content: content, path: path}]
  end

  defp warn_name(policy_name) do
    unless String.ends_with?(policy_name, "Policy") do
      IO.warn("Policy modules should have the 'Policy' suffix, e.g. '#{policy_name}Policy'", [])
    end
  end
end
