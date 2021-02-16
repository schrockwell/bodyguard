defmodule Bodyguard.Plug.Authorize do
  @behaviour Plug
  import Bodyguard.Utilities

  @moduledoc """
  Perform authorization in a Plug pipeline.

  ## Options

  * `:policy` *required* - the policy (or context) module
  * `:action` *required* - the action, or a getter
  * `:user` - the user getter
  * `:params` - the params, or a getter, to pass to the authorization callbacks
  * `:fallback` - a fallback controller or plug to handle authorization
    failure. If specified, the plug is called and then the pipeline is
    `halt`ed. If not specified, then `Bodyguard.NotAuthorizedError` raises
    directly to the router.

  ### Option Getters

  The options `:action`, `:user`, and `:params` can accept getter functions that are either:

  * an anonymous 1-arity function that accepts the `conn` and returns a value
  * a `{module, function_name}` tuple specifying an existing function with that same signature

  ### Default Plug Options

  You can provide default options for this plug by simply wrapping your own plug around it.
  For example, if you're using Phoenix with Pow for authentication, you might want to specify:

      defmodule MyAppWeb.Authorize do
        def init(opts) do
          opts
          |> Keyword.put_new(:action, {Phoenix.Controller, :action_name})
          |> Keyword.put_new(:user, {Pow.Plug, :current_user})
          |> Bodyguard.Plug.Authorize.init()
        end

        def call(conn, opts) do
          Bodyguard.Plug.Authorize.call(conn, opts)
        end
      end

  ## Examples

      # Raise on failure
      plug Bodyguard.Plug.Authorize,
        policy: MyApp.Blog,
        action: &action_name/1,
        user: {MyApp.Authentication, :current_user}

      # Fallback on failure
      plug Bodyguard.Plug.Authorize,
        policy: MyApp.Blog,
        action: &action_name/1,
        user: {MyApp.Authentication, :current_user},
        fallback: MyAppWeb.FallbackController

      # Params as a function
      plug Bodyguard.Plug.Authorize,
        policy: MyApp.Blog,
        action: &action_name/1,
        user: {MyApp.Authentication, :current_user},
        params: &get_params/1

  """

  def valid_getter?(fun) when is_function(fun, 1), do: true
  def valid_getter?({module, fun}) when is_atom(module) and is_atom(fun), do: true
  def valid_getter?(_), do: false

  def init(opts \\ []) do
    default_opts = Application.get_env(:bodyguard, __MODULE__, [])
    opts = Keyword.merge(default_opts, opts)

    policy = Keyword.get(opts, :policy)
    action = Keyword.get(opts, :action)
    user = Keyword.get(opts, :user)
    params = Keyword.get(opts, :params, [])
    fallback = Keyword.get(opts, :fallback)

    # Policy must be defined
    if is_nil(policy), do: raise(ArgumentError, "#{inspect(__MODULE__)} :policy option required")

    # Action must be defined
    if is_nil(action),
      do:
        raise(
          ArgumentError,
          "#{inspect(__MODULE__)} :action option is required"
        )

    # User can be nil or a getter function
    unless is_nil(user) || valid_getter?(user),
      do:
        raise(
          ArgumentError,
          "#{inspect(__MODULE__)} :user option #{inspect(user)} is invalid"
        )

    unless is_nil(fallback) or is_atom(fallback),
      do: raise(ArgumentError, "#{inspect(__MODULE__)} :fallback option must be a plug module")

    # Plug 1.0 through 1.3.2 doesn't support returning maps from init/1
    # See https://github.com/schrockwell/bodyguard/issues/52
    {fallback,
     [
       policy: policy,
       action: action,
       user: user,
       params: params
     ]}
  end

  def call(conn, {nil, opts}) do
    Bodyguard.permit!(
      opts[:policy],
      resolve_param_or_callback(conn, opts[:action]),
      resolve_param_or_callback(conn, opts[:user]),
      resolve_param_or_callback(conn, opts[:params])
    )

    conn
  end

  def call(conn, {fallback, opts}) do
    case Bodyguard.permit(
           opts[:policy],
           resolve_param_or_callback(conn, opts[:action]),
           resolve_param_or_callback(conn, opts[:user]),
           resolve_param_or_callback(conn, opts[:params])
         ) do
      :ok ->
        conn

      error ->
        conn
        |> fallback.call(error)
        |> Plug.Conn.halt()
    end
  end
end
