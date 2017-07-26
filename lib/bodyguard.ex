defmodule Bodyguard do
  @moduledoc """
  Authorize actions at the boundary of a context

  Please see the [README](readme.html).
  """

  @type opts :: keyword

  @doc """
  Authorize a user's action.

  Returns `:ok` on success, and `{:error, reason}` on failure.

  If `params` is a keyword list, it is converted to a map before passing down
  to the `c:Bodyguard.Policy.authorize/3` callback. Otherwise, `params` is not
  changed.
  """
  @spec permit(policy :: module, action :: atom, user :: any, params :: any) :: Bodyguard.Policy.auth_result
  def permit(policy, action, user, params \\ []) do
    params = cond do
      Keyword.keyword?(params) -> Enum.into(params, %{})
      true -> params
    end

    policy
    |> apply(:authorize, [action, user, params])
    |> resolve_result
  end

  @doc """
  The same as `permit/4`, but raises `Bodyguard.NotAuthorizedError` on
  authorization failure.

  Returns `:ok` on success.

  ## Options

  * `error_message` – a string to describe the error (default "not authorized")
  * `error_status` – the HTTP status code to raise with the error (default 403)

  The remaining `opts` are converted into a `params` map and passed to the
  `c:Bodyguard.Policy.authorize/3` callback.
  """

  @spec permit!(policy :: module, action :: atom, user :: any, opts :: opts) :: :ok
  def permit!(policy, action, user, opts \\ []) do
    opts = Enum.into(opts, %{})
    {error_message, opts} = Map.pop(opts, :error_message, "not authorized")
    {error_status, opts} = Map.pop(opts, :error_status, 403)

    case permit(policy, action, user, opts) do
      :ok -> :ok
      error -> raise Bodyguard.NotAuthorizedError,
        message: error_message, status: error_status, reason: error
    end
  end

  @doc """
  The same as `permit/4`, but returns a boolean.
  """
  @spec permit?(policy :: module, action :: atom, user :: any, opts :: opts) :: boolean
  def permit?(policy, action, user, opts \\ []) do
    case permit(policy, action, user, opts) do
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

  #### Options

  * `schema` - if the schema of the `query` cannot be determined, you must
    manually specify the schema here

  The remaining `opts` are converted to a `params` map and passed to the
  `c:Bodyguard.Schema.scope/3` callback on that schema.
  """
  @spec scope(query :: any, user :: any, opts :: keyword) :: any
  def scope(query, user, opts \\ []) do
    params = Enum.into(opts, %{})
    {schema, params} = Map.pop(params, :schema, resolve_schema(query))

    apply(schema, :scope, [query, user, params])
  end

  # Private

  # Ecto query (this feels dirty...)
  defp resolve_schema(%{__struct__: Ecto.Query, from: {_source, schema}})
    when is_atom(schema) and not is_nil(schema), do: schema

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
  defp resolve_result(invalid), do: raise "Unexpected authorization result: #{inspect(invalid)}"
end
