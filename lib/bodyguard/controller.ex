defmodule Bodyguard.Controller do
  @moduledoc """
  Include this module in your Phoenix/Plug controllers to gain wrapper
  functions for authorization.
  """

  @doc """
  Authorizes the controller action for the current user.

  On success, returns `{:ok, conn}` with a modified `conn` that is marked as authorized 
  (see `verify_authorized/2` ).

  On failure, returns `{:error, :unauthorized}` by default, or returns
  `{:error, reason}` if the policy function explicitly returns that.

      def index(conn, _params) do
        case authorize(conn, Post) do
          {:ok, conn} -> 
            # ...
          {:error, reason} ->
            # ...
        end
      end

      def show(conn, %{"id" => id}) do
        post = Repo.get(Post, id)
        case authorize(conn, post) do
          {:ok, conn} ->
            # ...
          {:error, reason} ->
            # ...
        end
      end

  Available options:
  * `action` (atom) - override the controller action picked up from `conn`
  * `user` (term) - override the current user picked up from `conn`
  * `policy` (atom) - override the policy determined from `term`
  """
  def authorize(conn, term, opts \\ []) do
    opts = merge_options(conn, opts)
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)
    explicit_policy = opts[:policy]

    if is_nil(term) && is_nil(explicit_policy) do
      # If no data to authorize, we can't determine the policy
      # module automatically (e.g. Repo.get returned nil)
      {:error, :unauthorized}
    else
      case Bodyguard.authorized?(user, action, term, opts) do
        success when success in [true, :ok] ->
          {:ok, mark_authorized(conn)}
        failure when failure in [false, :error] ->
          {:error, :unauthorized}
        {:error, reason} ->
          {:error, reason}
        unexpected ->
          raise "Unexpected result from policy function: #{inspect(unexpected)}"
      end
    end
  end

  @doc """
  Similar to `authorize/3` but returns a modified `conn` on success and
  raises `Bodyguard.NotAuthorizedError` on failure.

  Available options:
  * `action` (atom) - override the controller action picked up from `conn`
  * `user` (term) - override the current user picked up from `conn`
  * `policy` (atom) - override the policy determined from `term`
  * `error_message` (String) - override the default error message
  * `error_status` (integer) - override the default HTTP error code
  """
  def authorize!(conn, term, opts \\ []) do
    opts = merge_options(conn, opts)
    error_message = opts[:error_message] || "not authorized"
    error_status = opts[:error_status] || 403

    case authorize(conn, term, opts) do
      {:ok, conn} -> conn
      {:error, reason} ->
        raise Bodyguard.NotAuthorizedError,
          message: error_message,
          status: error_status,
          reason: reason
    end
  end

  @doc """
  Scopes the current resource based on the action and user.

  If the `scope` argument is a struct, module name, or an Ecto query, the schema
  can be automatically inferred. Otherwise, you must pass the `policy` option to
  explicitly determine the policy.

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
  def scope(conn, scope, opts \\ []) do
    opts = merge_options(conn, opts)
    action = opts[:action] || get_action(conn)
    user = opts[:user] || get_current_user(conn)

    Bodyguard.scoped(user, action, scope, opts)
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
    opts = merge_options(conn, opts)
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
    opts = merge_options(conn, opts)
    error_message = opts[:error_message] || "no authorization run"
    error_status = opts[:error_status] || 403

    Plug.Conn.register_before_send conn, fn (after_conn) ->
      unless after_conn.private[:bodyguard_authorized] do
        raise Bodyguard.NotAuthorizedError,
          message: error_message,
          status: error_status,
          reason: :no_authorization_run
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

  @doc """
  Retrieves the authenticated current user, previously assigned to the `conn`.

  By default, the assign key is `:current_user`, but this may be changed
  with the `:current_user` configuration option:

      config :bodyguard, current_user: :my_custom_assign_key
  """
  def get_current_user(conn) do
    key = Application.get_env(:bodyguard, :current_user, :current_user)
    conn.assigns[key]
  end

  @doc """
  A plug to set controller-wide authorization options.

  This is a controller plug to apply shared authorization options
  to all its actions. Any per-action options will be merged with 
  these default options.

  These defaults do *not* apply to the view helpers.

  For example, to specify a custom policy module for a controller:

      defmodule MyApp.DraftController do
        use MyApp.Web, :controller

        plug :put_bodyguard_options, policy: Post.DraftPolicy

        # Authorization checks in this controller will use
        # Post.DraftPolicy unless otherwise specified
      end
  """
  def put_bodyguard_options(conn, opts) do
    Plug.Conn.put_private(conn, :bodyguard_options, opts)
  end

  # Private

  defp get_action(conn) do
    conn.assigns[:action] || conn.private[:phoenix_action]
  end

  defp merge_options(%Plug.Conn{private: %{bodyguard_options: conn_options}}, opts) do
    Keyword.merge(conn_options, opts)
  end
  defp merge_options(_, opts), do: opts
end
