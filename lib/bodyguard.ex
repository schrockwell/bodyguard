defmodule Bodyguard do
  @moduledoc """
  Protect your stuff!

  See the [README](./readme.html) for documentation.

  ## Configuration Options

  * `:resolve_user` - see `resolve_user/1` for details
  """

  @doc """
  Authorize the user's actions.

  Returns `:ok` on authorization success, or `{:error, reason}` on failure.

  See `c:Bodyguard.Policy.permit/3` for how to define the callback functions.

  The `actor` can be a user itself, or a struct with `assigns` (such as a
  `Plug.Conn` or a `Phoenix.Socket`), in which case `assigns[:current_user]`
  is used. For more advanced cases, see `resolve_user/1`.

  The `opts` are converted into a `params` map and passed to the
  `c:Bodyguard.Policy.permit/3` callback.
  """

  @spec authorize(policy :: module, actor :: any, action :: atom, opts :: keyword)
    :: :ok | {:error, reason :: atom}

  def authorize(policy, actor, action, opts \\ []) do
    opts = merge_options(actor, opts)
    params = Enum.into(opts, %{})

    policy
    |> apply(:permit, [resolve_user(actor), action, params])
    |> validate_result!
  end

  @doc """
  The same as `authorize/3`, but raises `Bodyguard.NotAuthorizedError` on
  authorization failure.

  Returns `:ok` on success.

  ## Options
  
  * `error_message` – a string to describe the error (default "not authorized")
  * `error_status` – the HTTP status code to raise with the error (default 403)

  The remaining `opts` are converted into a `params` map and passed to the
  `c:Bodyguard.Policy.scope/4` callback.
  """

  @spec authorize!(actor :: any, context :: module, action :: atom, opts :: keyword)
    :: :ok

  def authorize!(policy, actor, action, opts \\ []) do
    opts = merge_options(actor, opts)

    {error_message, opts} = Keyword.pop(opts, :error_message, "not authorized")
    {error_status, opts} = Keyword.pop(opts, :error_status, 403)

    case authorize(policy, actor, action, opts) do
      :ok -> :ok
      {:error, reason} -> raise Bodyguard.NotAuthorizedError, 
        message: error_message, status: error_status, reason: reason
    end
  end

  @doc """
  The same as `authorize/3`, but returns a boolean.
  """
  @spec authorize?(actor :: any, context :: module, action :: atom, opts :: keyword)
    :: boolean

  def authorize?(policy, actor, action, opts \\ []) do
    case authorize(policy, actor, action, opts) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Limit the user's accessible resources.

  Returns a subset of the `scope` based on the user's access.

  See `c:Bodyguard.Policy.scope/4` for details on how to define the callback
  functions.

  All `opts` are converted into a `params` map and passed to the
  `c:Bodyguard.Policy.scope/4` callback.
  """

  @spec scope(policy :: module, actor :: any, action :: atom, scope :: any, opts :: keyword) :: any

  def scope(policy, actor, action, scope, opts \\ []) do
    opts = merge_options(actor, opts)
    params = Enum.into(opts, %{})

    apply(policy, :filter, [resolve_user(actor), action, scope, params])
  end

  @doc """
  Determine the particular user to authorize.

  By default, this defers to `get_current_user/1`. 

  Customize this behavior with the `:resolve_user` configuration option. The
  single `actor` argument passed to the callback might already be the user
  model itself.
      
      # config/config.exs
      config Bodyguard, :resolve_user, {MyApp.Authorization, :get_current_user}

      # lib/my_app/authorization.ex
      defmodule MyApp.Authorization do
        def get_current_user(%Plug.Conn{} = conn) do
          # return a user
        end
        def get_current_user(%MyApp.User{} = user), do: user
      end
  """

  @spec resolve_user(actor :: any) :: any

  def resolve_user(actor) do
    {module, function} = Application.get_env(:bodyguard, :resolve_user, {__MODULE__, :get_current_user})
    apply(module, function, [actor])
  end

  @doc """
  Extract the current user from a struct with assigns.

  The actor can be a user model, or a struct with an `assigns` key, such as
  `Plug.Conn` or `Phoenix.Socket`.
  """

  @spec get_current_user(actor :: any) :: any
  def get_current_user(%{assigns: assigns}) when is_map(assigns) do
    assigns[:current_user]
  end
  def get_current_user(actor), do: actor

  #
  # PRIVATE
  #

  #
  # Validate the result of a Bodyguard.Policy.guard/3 callback
  #
  defp validate_result!(:ok), do: :ok
  defp validate_result!({:error, reason}), do: {:error, reason}
  defp validate_result!(result) do
    raise ArgumentError, "Unexpected result from authorization function: #{inspect(result)}"
  end

  #
  # Merge in default options specified on the actor
  #
  defp merge_options(%Plug.Conn{private: %{bodyguard_options: conn_options}}, opts) do
    Keyword.merge(conn_options, opts)
  end
  defp merge_options(_, opts), do: opts
end