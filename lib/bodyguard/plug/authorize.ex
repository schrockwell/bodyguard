defmodule Bodyguard.Plug.Authorize do
  @behaviour Plug
  
  @moduledoc """
  Perform Action authorization in a Plug pipeline.

  The connection must contain an existing `Bodyguard.Action`, which can be
  done with `Bodyguard.Plug.BuildAction`.

  ## Options

  * `name` *required* - the action to authorize
  * `opts` - options to be passed down to the authorization functions
  * `fallback` - If authorization fails, the `fallback` plug is called and
    then the plug pipeline is `halt`ed. This is designed to work nicely with
    Phoenix fallback controllers.
  * `raise` - When no `fallback` is provided, set `false` to
    continue down the pipeline instead of raising.

  ## Examples

      # Raise on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts

      # Fallback on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts,
        fallback: MyApp.FallbackController

      # Continue on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts, raise: false
  """

  def init(opts \\ []) do
    name      = Keyword.get(opts, :name)
    auth_opts = Keyword.get(opts, :opts, [])
    do_raise  = Keyword.get(opts, :raise, true)
    fallback  = Keyword.get(opts, :fallback, nil)

    if is_nil(name), do: raise "#{inspect(__MODULE__)} requires a :name option"

    %{name: name, opts: auth_opts, raise: do_raise, fallback: fallback}
  end

  def call(conn, %{raise: true, name: name, opts: opts, fallback: nil}) do
    authorize_conn!(conn, name, opts)
  end
  def call(conn, %{raise: false, name: name, opts: opts, fallback: nil}) do
    authorize_conn(conn, name, opts)
  end
  def call(conn, %{raise: _, name: name, opts: opts, fallback: fallback}) do
    conn = authorize_conn(conn, name, opts)
    action = conn.assigns[:action]

    cond do
      is_nil(action) ->
        raise "No action assigned to this connection - use Bodyguard.Plug.BuildAction first"
      action.authorized? ->
        conn
      true ->
        conn
        |> fallback.call(action.auth_result)
        |> Plug.Conn.halt()
    end
  end

  # Private

  # Authorize the existing Action in-place on the connection.
  @spec authorize_conn(conn :: Plug.Conn.t, name :: atom, opts :: keyword) :: Plug.Conn.t
  defp authorize_conn(%Plug.Conn{} = conn, name, opts) do
    Bodyguard.Conn.update_action(conn, &Bodyguard.Action.authorize(&1, name, opts))
  end

  # Authorize the existing Action in-place on the connection, raising on failure.
  @spec authorize_conn!(conn :: Plug.Conn.t, name :: atom, opts :: keyword) :: Plug.Conn.t
  defp authorize_conn!(%Plug.Conn{} = conn, name, opts) do
    Bodyguard.Conn.update_action(conn, &Bodyguard.Action.authorize!(&1, name, opts))
  end
end