defmodule Bodyguard.Plug.Authorize do
  @behaviour Plug
  
  @moduledoc """
  Perform Action authorization in a Plug pipeline.

  The connection must contain an existing `Bodyguard.Action`, which can be
  done with `Bodyguard.Plug.BuildAction`.

  ## Options

  * `name` *required* - the action to authorize
  * `opts` - options to be passed down to the authorization functions
  * `raise` - `true` (default) to raise `Bodyguard.NotAuthorizedError` on
    failure, or `false` to continue down the pipeline, using the `fallback`
    if provided
  * `fallback` - If authorization fails and `raise` is `false`, the `fallback`
    plug is called and then the plug pipeline is `halt`ed. This is designed to
    work nicely with Phoenix fallback controllers.

  ## Examples

      # Raise on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts

      # Fallback on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts, raise: false,
        fallback: MyApp.FallbackController

      # Continue on failure
      plug Bodyguard.Plug.Authorize, name: :access_posts, raise: false
  """

  def init(opts \\ []) do
    name      = Keyword.get(opts, :name)
    auth_opts = Keyword.get(opts, :opts, [])
    do_raise  = Keyword.get(opts, :raise, true)
    fallback  = Keyword.get(opts, :fallback)

    if is_nil(name), do: raise "#{inspect(__MODULE__)} requires a :name option"

    %{name: name, opts: auth_opts, raise: do_raise, fallback: fallback}
  end

  def call(conn, %{raise: true, name: name, opts: opts}) do
    Bodyguard.Conn.authorize!(conn, name, opts)
  end
  def call(conn, %{raise: false, name: name, opts: opts, fallback: nil}) do
    Bodyguard.Conn.authorize(conn, name, opts)
  end
  def call(conn, %{raise: false, name: name, opts: opts, fallback: fallback}) do
    conn = Bodyguard.Conn.authorize(conn, name, opts)
    action = Bodyguard.Conn.get_action(conn)
    if action.authorized? do
      conn
    else
      conn
      |> fallback.call(action.auth_result)
      |> Plug.Conn.halt()
    end
  end
end