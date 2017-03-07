defmodule Bodyguard.Schema do
  @moduledoc """
  Specify user-accessible items.

  The callbacks are designed to live within your schemas, hidden from the
  context boundaries of your application.

  All you have to do is implement the `c:scope/3` callback on your schema.
  What "access" means is up to you, and can be customized on a case-by-case
  basis via `params`.
  """

  @type params :: %{atom => any}

  @doc """
  Specify user-accessible items.

  This callback is expected to take a `query` of this schema and filter it
  down to results that are only accessible to `user`. Arbitrary `params` may
  also be specified.

      defmodule MyApp.MyModel.MySchema do
        use Bodyguard.Schema
        import Ecto.Query, only: [from: 2]

        def scope(query, user, _) do
          from ms in query, where: ms.user_id == ^user.id
        end
      end
  """
  @callback scope(query :: any, user :: any, params :: params) :: any

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Schema

      if scope_with = Keyword.get(opts, :scope_with) do
        def scope(query, user, params \\ %{}) do
          unquote(scope_with).scope(query, user, params)
        end
      end
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
        import Bodyguard.Schema
        # ...

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
  `c:scope/3` callback on that schema.
  """
  @spec scope(query :: any, user :: any, opts :: keyword) :: any
  def scope(query, user, opts \\ []) do
    params = Enum.into(opts, %{})
    {params, schema} = Map.pop(params, :schema, resolve_schema(query))
    
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
end