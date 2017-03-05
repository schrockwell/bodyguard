defmodule Bodyguard.Conn do
  @moduledoc """
  Work with Actions embedded in connections.
  """

  alias Bodyguard.Action
  alias Plug.Conn

  @doc """
  Assign an Action to the connection.
  """
  @spec put_action(conn :: Plug.Conn.t, action :: Bodyguard.Action.t) :: Plug.Conn.t
  def put_action(%Conn{} = conn, %Action{} = action) do
    Plug.Conn.put_private(conn, :bodyguard_action, action)
  end

  @doc """
  Retrieve the Action from the connection.
  """
  @spec get_action(conn :: Plug.Conn.t) :: Bodyguard.Action.t
  def get_action(%Conn{} = conn) do
    conn.private[:bodyguard_action]
  end

  @doc """
  Modify the existing Action on the connection, in-place.
  """
  @spec update_action(conn :: Plug.Conn.t, fun :: (Bodyguard.Action.t -> Bodyguard.Action.t)) :: Plug.Conn.t
  def update_action(%Conn{} = conn, fun) when is_function(fun, 1) do
    put_action(conn, fun.(get_action(conn)))
  end

  @doc """
  Authorize the existing Action on the connection.
  """
  @spec authorize(conn :: Plug.Conn.t, name :: atom, opts :: keyword) :: Plug.Conn.t
  def authorize(%Conn{} = conn, name, opts \\ []) do
    update_action(conn, &Action.authorize(&1, name, opts))
  end

  @doc """
  Authorize the existing Action on the connection, raising on failure.
  """
  @spec authorize!(conn :: Plug.Conn.t, name :: atom, opts :: keyword) :: Plug.Conn.t
  def authorize!(%Conn{} = conn, name, opts \\ []) do
    update_action(conn, &Action.authorize!(&1, name, opts))
  end
end