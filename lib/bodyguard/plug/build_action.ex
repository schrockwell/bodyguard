defmodule Bodyguard.Plug.BuildAction do
  @behaviour Plug

  @moduledoc """
  Construct an Action on the connection.

  The action is stored in `conn.assigns.action` for later access (configurable
  via the `:key` option).

  #### Options

  See `Bodyguard.Action` for descriptions of these fields.

  * `context` - context module
  * `policy` - policy module (defaults to context module)
  * `fallback` - fallback function
  * `assigns` - action assigns
  * `user` – can be a 1-arity function that accepts the connection and returns
    the user
  * `key` - the assign to set. Defaults to `:action`
  """

  import Bodyguard.Action

  def init(opts \\ []), do: opts

  def call(conn, opts) do
    context = Keyword.get(opts, :context, nil)
    policy = Keyword.get(opts, :policy, context)
    user = Keyword.get(opts, :user, nil)
    fallback = Keyword.get(opts, :fallback, nil)
    assigns = Keyword.get(opts, :assigns, %{})
    key = Keyword.get(opts, :key, :action)

    user = if is_function(user, 1), do: user.(conn), else: user

    action =
      act(context)
      |> put_policy(policy)
      |> put_user(user)
      |> put_fallback(fallback)
      |> put_assigns(assigns)

    Bodyguard.Plug.put_action(conn, action, key)
  end
end
