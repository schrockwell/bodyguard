defmodule Bodyguard do
  @moduledoc """
  Authorize actions at the boundary of a context.

  Please see the [README](readme.html).
  """

  @doc """
  TODO
  """
  defdelegate permit?(policy, actor, action, context), to: Bodyguard.Policy

  @doc """
  TODO
  """
  defdelegate permit!(policy, actor, action, context), to: Bodyguard.Policy
end
