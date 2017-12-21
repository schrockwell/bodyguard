defmodule Bodyguard.Schema do
  @moduledoc """
  Specify user-accessible items.

  The callbacks are designed to live within your schemas, hidden from the
  context boundaries of your application.

  All you have to do is implement the `c:scope/3` callback on your schema.
  What "access" means is up to you, and can be customized on a case-by-case
  basis via `params`.

  Typically the callbacks are designed to be used by `Bodyguard.scope/4` and
  are not called directly.

  If you want to use separate module for scoping, you can use `defdelegate`:

      defmodule MyApp.MyModel.MySchema do
        defdelegate scope(query, user, params), to: Some.Other.Scope
      end
  """

  @doc """
  Specify user-accessible items.

  This callback is expected to take a `query` of this schema and filter it
  down to results that are only accessible to `user`. Arbitrary `params` may
  also be specified.

      defmodule MyApp.MyModel.MySchema do
        @behaviour Bodyguard.Schema
        import Ecto.Query, only: [from: 2]

        def scope(query, user, _params) do
          from ms in query, where: ms.user_id == ^user.id
        end
      end
  """
  @callback scope(query :: any, user :: any, params :: %{atom => any}) :: any

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Schema

      if scope_with = Keyword.get(opts, :scope_with) do
        IO.puts(
          "DEPRECATION WARNING - #{inspect(__MODULE__)}: `use Bodyguard.Schema` is deprecated. Please use defdelegate instead, like this:\n\n    defdelegate scope(query, user, params), to: #{
            inspect(scope_with)
          }\n"
        )

        defdelegate scope(query, user, params), to: scope_with
      end
    end
  end
end
