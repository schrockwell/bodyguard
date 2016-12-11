defmodule Bodyguard.ViewHelpers do
  @moduledoc """
  Convenience functions for view authorization.
  """

  @doc """
  Returns a boolean indicating authorization status for a particular resource.

  This is basically a thin wrapper around `Bodyguard.authorized?/4`, except 
  the first argument is more flexible, and this function always returns a boolean.

  The first argument may be either a user model or a `Plug.Conn` out of which
  the user model will be extracted – see `Bodyguard.Controller.get_current_user/1`.
  """
  def can?(conn_or_user, action, resource, opts \\ [])
  def can?(%Plug.Conn{} = conn, action, resource, opts) do
    can?(Bodyguard.Controller.get_current_user(conn), action, resource, opts)
  end
  def can?(user, action, resource, opts) do
    case Bodyguard.authorized?(user, action, resource, opts) do
      success when success in [true, :ok] -> true
      _ -> false
    end
  end
end