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

  Available options:
  * `action` (atom) - override the controller action picked up from conn
  * `user` (term) - override the current user picked up from conn
  * `policy` (atom) - override the policy determined from the term
  """
  def authorize(conn, term, opts \\ []) do
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)
    explicit_policy = opts[:policy]

    cond do
      is_nil(term) && is_nil(explicit_policy) -> {:error, :unauthorized}
      Bodyguard.authorized?(user, action, term, opts) -> {:ok, mark_authorized(conn)}
      true -> {:error, :unauthorized}
    end
  end

  @doc """
  Similar to `authorize/3` but raises `Bodyguard.NotAuthorizedError` if no record was found.

  Available options:
  * `action` (atom) - override the controller action picked up from conn
  * `user` (term) - override the current user picked up from conn
  * `policy` (atom) - override the policy determined from the term
  * `error_message` (String) - override the default error message
  * `error_status` (integer) - override the default HTTP error code
  """
  def authorize!(conn, term, opts \\ []) do
    error_message = opts[:error_message] || "not authorized"
    error_status = opts[:error_status] || 403

    case authorize(conn, term, opts) do
      {:ok, conn} -> conn
      {:error, _reason} ->
        raise Bodyguard.NotAuthorizedError,
          message: error_message,
          status: error_status
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

  Available options:
  * `action` (atom) - override the controller action picked up from conn
  * `user` (term) - override the current user picked up from conn
  * `policy` (atom) - override the policy determined from the term
  """
  def scope(conn, term, opts \\ []) do
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)

    Bodyguard.scoped(user, action, term, opts)
  end

  @doc """
  Whitelists parameters based on the current user. 

  The result can be passed into `Ecto.Changeset.cast/3` if you are constructing
  the changeset in your controller. If you are using service modules or 
  constructing a changeset elsewhere, then you don't need this function – 
  call `Bodyguard.permitted_attributes/3` directly instead.

  Available options:
  * `user` (term) - override the current user picked up from conn
  * `policy` (atom) - override the policy determined from the term  
  """
  def permitted_attributes(conn, term, opts \\ []) do
    user = opts[:user] || get_current_user(conn)
    Bodyguard.permitted_attributes(user, term, opts)
  end

  @doc """
  Raises `Bodyguard.NotAuthorizedError` if the `conn` tries to send without any authorization being run.

  This is mainly used as a function plug on your controller.

  Available options:
  * `error_message` (String) - override the default error message
  * `error_status` (integer) - override the default HTTP error code
  """
  def verify_authorized(conn, opts \\ []) do
    error_message = opts[:error_message] || "no authorization run"
    error_status = opts[:error_status] || 403

    Plug.Conn.register_before_send conn, fn (after_conn) ->
      unless after_conn.private[:bodyguard_authorized] do
        raise Bodyguard.NotAuthorizedError,
          message: error_message,
          status: error_status
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



  defp get_current_user(conn) do
    key = Application.get_env(:bodyguard, :current_user, :current_user)
    conn.assigns[key]
  end

  defp get_action(conn) do
    conn.assigns[:action] || conn.private[:phoenix_action]
  end
end
