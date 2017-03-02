defmodule Bodyguard.Conn do
  @doc """
  Manually marks a `conn` as successfully authorized. This is mainly used to
  satisfy `verify_authorized/2` when authorization is performed outside of
  Bodyguard.
  """

  @spec mark_authorized(Plug.Conn.t) :: Plug.Conn.t

  def mark_authorized(conn) do
    Plug.Conn.put_private(conn, :bodyguard_authorized, true)
  end

  @spec authorized?(Plug.Conn.t) :: boolean

  def authorized?(conn) do
    Map.get(conn.private, :bodyguard_authorized, false)
  end

  @spec authorize(Plug.Conn.t, module, atom, keyword) :: {:ok, Plug.Conn.t} | {:error, atom}

  def authorize(conn, policy, action, opts \\ []) do
    case Bodyguard.authorize(policy, conn, action, opts) do
      :ok -> {:ok, mark_authorized(conn)}
      error -> error
    end
  end

  @spec authorize!(Plug.Conn.t, module, atom, keyword) :: Plug.Conn.t
  
  def authorize!(conn, policy, action, opts \\ []) do
    Bodyguard.authorize!(policy, conn, action, opts)
    mark_authorized(conn)
  end  
end