defmodule Bodyguard.Plug.Authorize do
  @behaviour Plug

  @moduledoc """
  Perform authorization in a Plug pipeline.

  ## Options

  * `policy` *required* - the policy (or context) module
  * `action` *required* - the action to authorize, either an atom or a 1-arity
    function that accepts a conn and returns the action
  * `user` - a 1-arity function which accepts the connection and returns a
    user. If omitted, defaults `user` to `nil`
  * `params` - params to pass to the authorization callbacks or a 1-arity function which accepts the connection
  * `fallback` - a fallback controller or plug to handle authorization
    failure. If specified, the plug is called and then the pipeline is
    `halt`ed. If not specified, then `Bodyguard.NotAuthorizedError` raises
    directly to the router.

  ## Examples

      # Raise on failure
      plug Bodyguard.Plug.Authorize, policy: MyApp.Blog, action: :update_posts,
        user: &get_current_user/1

      # Fallback on failure
      plug Bodyguard.Plug.Authorize, policy: MyApp.Blog, action: :update_posts,
        user: &get_current_user/1, fallback: MyApp.FallbackController

      # Params as a function
      plug Bodyguard.Plug.Authorize, policy: MyApp.Blog, action: :update_posts,
        params: &get_params/1

  """

  def init(opts \\ []) do
    policy = Keyword.get(opts, :policy)
    action = Keyword.get(opts, :action)
    user_fun = Keyword.get(opts, :user)
    params = Keyword.get(opts, :params, [])
    fallback = Keyword.get(opts, :fallback)

    if is_nil(policy), do: raise(ArgumentError, "#{inspect(__MODULE__)} :policy option required")

    if action == nil or not (is_atom(action) or is_function(action, 1)),
      do:
        raise(
          ArgumentError,
          "#{inspect(__MODULE__)} :action option required - must be an atom or 1-arity function that accepts conn and returns the action"
        )

    unless is_nil(user_fun) or is_function(user_fun, 1),
      do:
        raise(
          ArgumentError,
          "#{inspect(__MODULE__)} :user option must be a 1-arity function that accepts conn and returns a user"
        )

    if is_function(params) and not is_function(params, 1),
      do:
        raise(
          ArgumentError,
          "#{inspect(__MODULE__)} :params option as a function must be a 1-arity function that accepts conn"
        )

    unless is_nil(fallback) or is_atom(fallback),
      do: raise(ArgumentError, "#{inspect(__MODULE__)} :fallback option must be a plug module")

    # Plug 1.0 through 1.3.2 doesn't support returning maps from init/1
    # See https://github.com/schrockwell/bodyguard/issues/52
    {fallback,
     [
       policy: policy,
       action: action,
       user_fun: user_fun,
       params: params
     ]}
  end

  def call(conn, {nil, opts}) do
    Bodyguard.permit!(
      opts[:policy],
      get_action(conn, opts[:action]),
      get_user(conn, opts[:user_fun]),
      get_params(conn, opts[:params])
    )

    conn
  end

  def call(conn, {fallback, opts}) do
    case Bodyguard.permit(
           opts[:policy],
           get_action(conn, opts[:action]),
           get_user(conn, opts[:user_fun]),
           get_params(conn, opts[:params])
         ) do
      :ok ->
        conn

      error ->
        conn
        |> fallback.call(error)
        |> Plug.Conn.halt()
    end
  end

  defp get_user(conn, user_fun) when is_function(user_fun, 1) do
    user_fun.(conn)
  end

  defp get_user(_conn, nil), do: nil

  defp get_action(conn, action_fun) when is_function(action_fun, 1) do
    action_fun.(conn)
  end

  defp get_action(_conn, action), do: action

  defp get_params(conn, params_fun) when is_function(params_fun, 1) do
    params_fun.(conn)
  end

  defp get_params(_conn, params), do: params
end
