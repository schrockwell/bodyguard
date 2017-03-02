defmodule Bodyguard do
  @moduledoc """
  Protect your stuff!

  ## Configuration

  When authorizing a `Plug.Conn` or `Phoenix.Socket` (or anything else with an
  `assigns` map), Bodyguard's default behavior is to use
  `assigns[:current_user]` as the current user. This behavior can be customized
  using the `:resolve_user` configuration option.

  Keep in mind that the single `actor` argument passed to the callback might
  already be the user model itself.
      
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

  @type user :: any
  @type actor :: Plug.Conn.t | user

  @doc """
  Authorize the user's actions.

  Returns `:ok` on authorization success, or `{:error, reason}` on failure.

  See `Bodyguard.Policy.guard/3` for details on how to define the callback
  functions in the policy.

  Out of the box, the `actor` can be a user itself, or a struct with `assigns`
  (such as a `Plug.Conn` or a `Phoenix.Socket`), in which case
  `assigns[:current_user]` is used. For more advanced mappings, see the
  `:resolve_user` configuration option.

  The `context` is a module whose functions are being authorized. By convention,
  the policy for this context is named `[context].Policy`.

  ## Options

  * `policy` - specify an explicit policy

  All remaining options are converted into a `params` map and passed to the
  `Bodyguard.Policy.guard/3` callback.
  """

  @spec permit(actor :: actor, context :: module, action :: atom, opts :: keyword)
    :: :ok | {:error, :unauthorized} | {:error, reason :: atom}

  def permit(policy, actor, action, opts \\ []) do
    opts = merge_options(actor, opts)
    params = Enum.into(opts, %{})

    policy
    |> apply(:guard, [resolve_user(actor), action, params])
    |> validate_result!
  end

  @doc """
  The same as `guard/4`, but raises `Bodyguard.NotAuthorizedError` on
  authorization failure.

  Returns `:ok` on success.
  """

  @spec permit!(actor :: actor, context :: module, action :: atom, opts :: keyword)
    :: :ok

  def permit!(policy, actor, action, opts \\ []) do
    opts = merge_options(actor, opts)

    {error_message, opts} = Keyword.pop(opts, :error_message, "not authorized")
    {error_status, opts} = Keyword.pop(opts, :error_status, 403)

    case permit(policy, actor, action, opts) do
      :ok -> :ok
      {:error, reason} -> raise Bodyguard.NotAuthorizedError, 
        message: error_message, status: error_status, reason: reason
    end
  end

  @doc """
  The same as `guard/4`, but returns a boolean.
  """
  @spec can?(actor :: actor, context :: module, action :: atom, opts :: keyword)
    :: boolean

  def can?(policy, actor, action, opts \\ []) do
    case permit(policy, actor, action, opts) do
      :ok -> true
      _ -> false
    end
  end


  @doc """
  Limit the user's accessible resources.

  Returns a subset of the `scope` based on the user's access.

  See `Bodyguard.Policy.scope/4` for details on how to define the callback
  functions in the policy.

  Bodyguard will attempt to infer the type of the data embodied by the `scope`:

  * If `scope` is a module, that module will be the `resource`.
  * If `scope` is an `Ecto.Query`, the schema module will be the `resource`.
  * If `scope` is a struct, the struct module will be the `resource`.
  * If `scope` is a list, the first item in the list will be the `resource` 
  using the above rules.
  * Otherwise, the `resource` option must be supplied.

  ## Options

  * `policy` - overrides the default policy convention of `context.Policy`
  * `resource` - if the resource type cannot be inferred from the `scope`
    argument, then you can specify it here

  All remaining options are converted into a `params` map and passed to the
  `Bodyguard.Policy.scope/4` callback.
  """

  @spec scope(actor :: actor, context :: module, scope :: any, opts :: keyword) :: any

  def scope(policy, actor, scope, opts \\ []) do
    opts = merge_options(actor, opts)

    {resource, opts} = Keyword.pop(opts, :resource, infer_resource!(scope))
    params = Enum.into(opts, %{})

    apply(policy, :scope, [resolve_user(actor), resource, scope, params])
  end

  @doc false
  def resolve_user(actor) do
    {module, function} = Application.get_env(:bodyguard, :resolve_user, {__MODULE__, :get_current_user})
    apply(module, function, [actor])
  end

  @doc false
  def get_current_user(%{assigns: assigns}) when is_map(assigns) do
    assigns[:current_user]
  end
  def get_current_user(user), do: user

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
  # Attempt to discover the type of a scope
  #
  defp infer_resource!(resource) when is_atom(resource), do: resource
  defp infer_resource!(list) when is_list(list) do
    list |> List.first |> infer_resource!
  end
  defp infer_resource!(%{__struct__: Ecto.Query, from: {_source, schema}}), do: schema
  defp infer_resource!(%{__struct__: struct}), do: struct
  defp infer_resource!(scope) do
    raise ArgumentError, "Unable to infer resource type given scope #{inspect(scope)}"
  end

  #
  # Merge in default options specified on the Plug.Conn
  #
  defp merge_options(%Plug.Conn{private: %{bodyguard_options: conn_options}}, opts) do
    Keyword.merge(conn_options, opts)
  end
  defp merge_options(_, opts), do: opts
end