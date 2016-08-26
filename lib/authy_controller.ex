defmodule Authy.Controller do
  @moduledoc """
  Import this in your Phoenix or Plug application controller to gain convenience functions
  for doing authorization.
  """
  defmacro authorize(term, opts \\ [], [do: block]) do
    quote do
      case Authy.Controller.Helpers.conn_authorization(var!(conn), unquote(term), unquote(opts)) do
        :authorized -> unquote(block)
        :unauthorized -> Authy.Controller.Helpers.unauthorized!(var!(conn))
        :not_found -> Authy.Controller.Helpers.not_found!(var!(conn))
      end
    end
  end

  defmacro scope(term, opts \\ []) do
    quote do
      Authy.Controller.Helpers.conn_scope(var!(conn), unquote(term), unquote(opts))
    end
  end
end

defmodule Authy.Controller.Helpers do
  @moduledoc """
  These are behind-the-scenes methods for handling controller authorization. These
  are only exported because the macros need to call them from other modules, 
  and we don't want to clutter up controller modules with helper functions
  when Authy.Controller is imported. You probably don't need to call 
  these functions directly.
  """

  @doc """
  Returns an atom specifying the authorization status for the current 
  controller action. Typically this is not called directly by the developer,
  only indirectly through the Authy.Controller.authorize/2 macro.

  Available options:

  * nils: :unauthorized (default) or :not_found - action to take when resource is nil
  * action: atom - override the controller action picked up from conn
  * user: term - override the current user picked up from conn
  * policy: atom - override the policy determined from the term
  """
  def conn_authorization(conn, term, opts) do
    # Figure out which function to call in the event of a nil term -
    # :unauthorized (default) or :not_found
    nil_function = opts[:nils] || Application.get_env(:authy, :nils, :unauthorized)
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)

    cond do
      is_nil(term) -> nil_function
      Authy.authorized?(user, action, term, opts) -> :authorized
      true -> :unauthorized
    end
  end

  @doc """
  Returns a resource scope for a given controller action. Typically this is not 
  called directly by the developer, only indirectly through the 
  Authy.Controller.scope/2 macro.

  Available options:

  * action: atom - override the controller action picked up from conn
  * user: term - override the current user picked up from conn
  * policy: atom - override the policy determined from the term  
  """
  def conn_scope(conn, term, opts \\ []) do
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)
    Authy.scoped(user, action, term, opts)
  end

  @doc """
  Call the "unauthorized" handler on the configured module. Raises a RuntimeError
  if that handler is not configured.
  """
  def unauthorized!(conn) do
    case Application.get_env(:authy, :unauthorized_handler) do
      nil 
        -> raise "You must configure an unauthorized_handler for Authy in your config.exs, 
        like this: config :authy, unauthorized_handler: {MyHandlerModule, :handle_unauthorized}"
      {module, function} 
        -> apply(module, function, [conn])
    end
  end

  @doc """
  Call the "not found" handler on the configured module. Raises a RuntimeError
  if that handler is not configured.
  """
  def not_found!(conn) do
    case Application.get_env(:authy, :not_found_handler) do
      nil 
        -> raise "You must configure an not_found_handler for Authy in your config.exs, 
        like this: config :authy, not_found_handler: {MyHandlerModule, :handle_not_found}"
      {module, function} 
        -> apply(module, function, [conn])
    end
  end

  defp get_current_user(conn) do
    conn.assigns[Application.get_env(:authy, :current_user, :current_user)]
  end

  defp get_action(conn) do
    conn.assigns[:action] || conn.private[:phoenix_action]
  end
end