defmodule Bodyguard.Controller do
  @moduledoc """
  Import this in your Phoenix or Plug application controller to gain convenience
  functions for performing authorization.
  """

  @doc """
  Authorizes the controller action for the current user and executes the given block if successful.

      def index(conn, _params) do
        {:ok, conn} = authorize(conn, Post)
        # ...
      end

      def show(conn, %{"id" => id}) do
        post = Repo.get(Post, id)
        {:ok, conn} = authorize(conn, post)
        # ...
      end
  """
  def authorize(conn, term, opts \\ []) do
    case Bodyguard.Controller.Helpers.conn_authorization(conn, term, opts) do
      :authorized -> {:ok, mark_authorized(conn)}
      :unauthorized -> {:error, :unauthorized}
      :not_found -> {:error, :not_found}
    end
  end

  @doc """
  Similar to `authorize/3` but raises `Bodyguard.NotAuthorizedError` if no record was found.
  """
  def authorize!(conn, term, opts \\ []) do
    case authorize(conn, term, opts) do
      {:ok, conn} -> conn
      {:error, _reason} -> 
        raise Bodyguard.NotAuthorizedError,
          message: "not authorized", 
          status: Bodyguard.Controller.Helpers.error_status(opts)
    end
  end

  @doc """
  Scopes the current resource based on the action and user.

      def index(conn, _params) do
        {:ok, conn} = authorize(conn, Post)
        posts = scope(conn, Post) |> Repo.all
        # ...
      end

      def show(conn, %{id: id}) do
        post = scope(conn, Post) |> Repo.get(id)
        {:ok, conn} = authorize(conn, post)
        # ...
      end
  """
  def scope(conn, term, opts \\ []) do
    Bodyguard.Controller.Helpers.conn_scope(conn, term, opts)
  end

  @doc """
  Raises `Bodyguard.NotAuthorizedError` if the `conn` tries to send without any authorization being run.

  This is mainly used as a function plug on your controller.
  """
  def verify_authorized(conn, opts \\ []) do
    Plug.Conn.register_before_send conn, fn (after_conn) ->
      unless after_conn.private[:bodyguard_authorized] do
        raise Bodyguard.NotAuthorizedError, 
          message: "no authorization run",
          status: Bodyguard.Controller.Helpers.error_status(opts)
      end

      after_conn
    end
  end

  @doc """
  Manually marks a `conn` as successfully authorized.

  This is mainly used to satisfy `verify_authorized/2` when authorization is performed outside of Bodyguard.
  """
  def mark_authorized(conn) do
    Plug.Conn.put_private(conn, :bodyguard_authorized, true)
  end
end

defmodule Bodyguard.Controller.Helpers do
  @moduledoc """
  These are behind-the-scenes methods for handling controller authorization. These
  are only exported because the macros need to call them from other modules,
  and we don't want to clutter up controller modules with helper functions
  when Bodyguard.Controller is imported.

  You probably don't need to call these functions directly.
  """

  @doc """
  Returns an atom specifying the authorization status for the current
  controller action. Typically this is not called directly by the developer,
  only indirectly through the Bodyguard.Controller.authorize/2 macro.

  Available options:

  * nils: :unauthorized (default) or :not_found - action to take when resource is nil
  * action: atom - override the controller action picked up from conn
  * user: term - override the current user picked up from conn
  * policy: atom - override the policy determined from the term
  """
  def conn_authorization(conn, term, opts) do
    # Figure out which function to call in the event of a nil term -
    # :unauthorized (default) or :not_found
    nil_function = opts[:nils] || Application.get_env(:bodyguard, :nils, :unauthorized)
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)

    cond do
      is_nil(term) -> nil_function
      Bodyguard.authorized?(user, action, term, opts) -> :authorized
      true -> :unauthorized
    end
  end

  @doc """
  Returns a resource scope for a given controller action. Typically this is not
  called directly by the developer, only indirectly through the
  Bodyguard.Controller.scope/2 macro.

  Available options:

  * action: atom - override the controller action picked up from conn
  * user: term - override the current user picked up from conn
  * policy: atom - override the policy determined from the term
  """
  def conn_scope(conn, term, opts \\ []) do
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)
    Bodyguard.scoped(user, action, term, opts)
  end

  @doc """
  Returns the Plug error status to be raised by `Bodyguard.NotAuthorizedError`.
  Returns 403 by default, but will be overridden by `opts[:error_status]`
  if provided.
  """
  def error_status(opts \\ []) do
    opts[:error_status] || 403
  end

  defp get_current_user(conn) do
    key = Application.get_env(:bodyguard, :current_user, :current_user)
    conn.assigns[key]
  end

  defp get_action(conn) do
    conn.assigns[:action] || conn.private[:phoenix_action]
  end
end
