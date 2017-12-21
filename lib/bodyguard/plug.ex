defmodule Bodyguard.Plug do
  @moduledoc """
  Work with Actions embedded in connections.
  """

  alias Bodyguard.Action
  alias Plug.Conn

  @doc """
  Assign an Action to the connection.

  Inserts it into `conn.assigns.action`.
  """
  @spec put_action(conn :: Plug.Conn.t(), action :: Bodyguard.Action.t(), key :: atom) ::
          Plug.Conn.t()
  def put_action(%Conn{} = conn, %Action{} = action, key \\ :action) do
    Plug.Conn.assign(conn, key, action)
  end

  @doc """
  Modify the existing Action on the connection, in-place.
  """
  @spec update_action(
          conn :: Plug.Conn.t(),
          fun :: (Bodyguard.Action.t() -> Bodyguard.Action.t()),
          key :: atom
        ) :: Plug.Conn.t()
  def update_action(%Conn{} = conn, fun, key \\ :action) when is_function(fun, 1) do
    put_action(conn, fun.(conn.assigns[key]))
  end
end
