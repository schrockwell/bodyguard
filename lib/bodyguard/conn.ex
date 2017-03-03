defmodule Bodyguard.Conn do
  @moduledoc """
  Functions to work with Plug connections.
  """

  @doc """
  Manually mark a connection as successfully authorized.

  This allows the `Bodyguard.Plug.VerifyAuthorizedAfter` to pass inspection,
  even in the absence of an authorization check.
  """
  @spec mark_authorized(Plug.Conn.t) :: Plug.Conn.t

  def mark_authorized(conn) do
    Plug.Conn.put_private(conn, :bodyguard_authorized, true)
  end

  @doc """
  Determine if authorization has already been performed on a connection.
  """
  @spec authorized?(Plug.Conn.t) :: boolean

  def authorized?(conn) do
    Map.get(conn.private, :bodyguard_authorized, false)
  end

  @doc """
  Perform authorization on a connection.

  On authorization success, returns `{:ok, conn}` with a modified `conn` that
  is flagged as authorized.

  On failure, returns an `{:error, :reason}`.

  See `Bodyguard.authorize/4` for more details.
  """
  @spec authorize(Plug.Conn.t, module, atom, keyword) :: {:ok, Plug.Conn.t} | {:error, reason :: atom}

  def authorize(conn, policy, action, opts \\ []) do
    case Bodyguard.authorize(policy, conn, action, opts) do
      :ok -> {:ok, mark_authorized(conn)}
      error -> error
    end
  end

  @doc """
  Perform authorization on a connection.

  On authorization success, returns a modified `conn` that is flagged as
  authorized.

  On failure, raises `Bodyguard.NotAuthorizedError` to the router.

  See `Bodyguard.authorize!/4` for more details.
  """
  @spec authorize!(Plug.Conn.t, module, atom, keyword) :: Plug.Conn.t
  
  def authorize!(conn, policy, action, opts \\ []) do
    Bodyguard.authorize!(policy, conn, action, opts)
    mark_authorized(conn)
  end  
end