defmodule Bodyguard.NotAuthorizedError do
  @moduledoc """
  Raised when authorization fails.
  """
  defexception [:policy, :actor, :action, :context]

  def message(%{policy: policy, action: action}) do
    "#{inspect(policy)} failed to authorize action #{inspect(action)}"
  end
end
