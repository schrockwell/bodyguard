defmodule Bodyguard.Plug.BuildAction do
  @behaviour Plug

  @moduledoc """
  Construct an Action on the connection.

  #### Options

  See `Bodyguard.Action` for descriptions of these fields.

  * `context`
  * `policy`
  * `user` – can be a 1-arity function that accepts the connection and returns the user
  * `fallback`
  * `assigns`
  """

  import Bodyguard.Action

  def init(opts \\ []), do: opts

  def call(conn, opts) do
    context  = Keyword.get(opts, :context)
    policy   = Keyword.get(opts, :policy, context)
    user     = Keyword.get(opts, :user)
    fallback = Keyword.get(opts, :fallback)
    assigns  = Keyword.get(opts, :assigns)

    user = if is_function(user, 1), do: user.(conn), else: user

    action =
      act(context)
      |> put_policy(policy)
      |> put_user(user)
      |> put_fallback(fallback)
      |> put_assigns(assigns)
      
    Bodyguard.Conn.put_action(conn, action)
  end
end