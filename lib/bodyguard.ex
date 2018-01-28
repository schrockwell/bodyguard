defmodule Bodyguard do
  @moduledoc """
  Authorize actions at the boundary of a context

  Please see the [README](readme.html).
  """

  @type opts :: keyword | %{optional(atom) => any}

  @doc """
  Authorize a user's action.

  Returns `:ok` on success, and `{:error, reason}` on failure.

  If `params` is a keyword list, it is converted to a map before passing down
  to the `c:Bodyguard.Policy.authorize/3` callback. Otherwise, `params` is not
  changed.
  """
  @spec permit(policy :: module, action :: atom, user :: any, params :: any) ::
          :ok | {:error, any} | no_return()
  def permit(policy, action, user, params \\ []) do
    params = try_to_mapify(params)

    policy
    |> apply(:authorize, [action, user, params])
    |> resolve_result()
  end

  @doc """
  The same as `permit/4`, but raises `Bodyguard.NotAuthorizedError` on
  authorization failure.

  Returns `:ok` on success.

  If `params` is a keyword list, it is converted to a map before passing down
  to the `c:Bodyguard.Policy.authorize/3` callback. Otherwise, `params` is not
  changed.

  ## Options

  * `error_message` – a string to describe the error (default "not authorized")
  * `error_status` – the HTTP status code to raise with the error (default 403)
  """

  @spec permit!(policy :: module, action :: atom, user :: any, params :: any, opts :: opts) ::
          :ok | no_return()
  def permit!(policy, action, user, params \\ [], opts \\ []) do
    params = try_to_mapify(params)
    opts = Enum.into(opts, %{})

    {error_message, params} =
      get_option("Bodyguard.permit!/5", params, opts, :error_message, "not authorized")

    {error_status, params} = get_option("Bodyguard.permit!/5", params, opts, :error_status, 403)

    case permit(policy, action, user, params) do
      :ok ->
        :ok

      error ->
        raise Bodyguard.NotAuthorizedError,
          message: error_message,
          status: error_status,
          reason: error
    end
  end

  @doc """
  The same as `permit/4`, but returns a boolean.
  """
  @spec permit?(policy :: module, action :: atom, user :: any, params :: any) :: boolean
  def permit?(policy, action, user, params \\ []) do
    case permit(policy, action, user, params) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Filter a query down to user-accessible items.

  The `query` is introspected by Bodyguard in an attempt to automatically
  determine the schema type. To succeed, `query` must be an atom (schema
  module name), an `Ecto.Query`, or a list of structs.

  This function exists primarily as a helper to `import` into a context and
  gain access to scoping for all schemas.

      defmodule MyApp.Blog do
        import Bodyguard

        def list_user_posts(user) do
          Blog.Post
          |> scope(user)          # <-- defers to MyApp.Blog.Post.scope/3
          |> where(draft: false)
          |> Repo.all
        end
      end

  If `params` is a keyword list, it is converted to a map before passing down
  to the `c:Bodyguard.Policy.authorize/3` callback. Otherwise, `params` is not
  changed.

  #### Options

  * `schema` - if the schema of the `query` cannot be determined, you must
    manually specify the schema here
  """
  @spec scope(query :: any, user :: any, params :: any, opts :: opts) :: any
  def scope(query, user, params \\ [], opts \\ []) do
    params = try_to_mapify(params)
    opts = Enum.into(opts, %{})

    {schema, params} =
      get_option("Bodyguard.scope/4", params, opts, :schema, resolve_schema(query))

    apply(schema, :scope, [query, user, params])
  end

  # Private

  # Attempts to convert a keyword list to a map
  defp try_to_mapify(params) do
    cond do
      Keyword.keyword?(params) -> Enum.into(params, %{})
      true -> params
    end
  end

  # Pulls an option from the `params` argument if possible, falling back on
  # the new `opts` argument. Returns {option_value, params}
  defp get_option(name, params, opts, key, default) do
    if is_map(params) and Map.has_key?(params, key) do
      # Treat the new `params` as the old `opts`
      IO.puts(
        "DEPRECATION WARNING - Please pass the #{inspect(key)} option to the new `opts` argument in #{
          name
        }."
      )

      Map.pop(params, key, default)
    else
      # Ignore `params` and just get it from `opts`
      {Map.get(opts, key, default), params}
    end
  end

  # Ecto query (this feels dirty...)
  defp resolve_schema(%{__struct__: Ecto.Query, from: {_source, schema}})
       when is_atom(schema) and not is_nil(schema),
       do: schema

  # List of structs
  defp resolve_schema([%{__struct__: schema} | _rest]), do: schema

  # Schema module itself
  defp resolve_schema(schema) when is_atom(schema), do: schema

  # Unable to determine
  defp resolve_schema(unknown) do
    raise ArgumentError, "Cannot automatically determine the schema of
      #{inspect(unknown)} - specify the :schema option"
  end

  # Coerce auth results
  defp resolve_result(true), do: :ok
  defp resolve_result(:ok), do: :ok
  defp resolve_result(false), do: {:error, :unauthorized}
  defp resolve_result(:error), do: {:error, :unauthorized}
  defp resolve_result({:error, reason}), do: {:error, reason}
  defp resolve_result(invalid), do: raise("Unexpected authorization result: #{inspect(invalid)}")
end
