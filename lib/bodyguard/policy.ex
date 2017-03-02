defmodule Bodyguard.Policy do
  @moduledoc """
  Behaviour to authorize actions within a context.

  Implement this behaviour for each context that will be authorized. 
  The module naming convention is `MyApp.MyContext.Policy`.
  """

  defmacro __using__(_) do
    quote do
      @doc false
      def authorize(actor, action, opts \\ []) do
        Bodyguard.authorize(__MODULE__, actor, action, opts)
      end

      @doc false
      def authorize!(actor, action, opts \\ []) do
        Bodyguard.authorize!(__MODULE__, actor, action, opts)
      end

      @doc false
      def authorize?(actor, action, opts \\ []) do
        Bodyguard.authorize?(__MODULE__, actor, action, opts)
      end

      @doc false
      def scope(actor, scope, opts \\ []) do
        Bodyguard.scope(__MODULE__, actor, scope, opts)
      end

      @doc false
      def authorize_conn(conn, action, opts \\ []) do
        Bodyguard.Conn.authorize(conn, __MODULE__, action, opts)
      end

      @doc false
      def authorize_conn!(conn, action, opts \\ []) do
        Bodyguard.Conn.authorize!(conn, __MODULE__, action, opts)
      end

      defoverridable [authorize: 3, authorize!: 3, authorize?: 3, scope: 3,
        authorize_conn: 3, authorize_conn!: 3]
    end
  end

  @doc """
  Authorize a user's action.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic mapping to a controller "action".

  To permit an action, return `:ok`.

  To deny authorization, return `{:error, reason}`.
  """
  @callback permit(user :: any, action :: atom, params :: map) 
    :: :ok | {:error, reason :: atom}

  @doc """
  Limit which resources a user can access.

  The `resource` is the module of the particular struct/schema/model that is being scoped.

  The `scope` argument is a broad specification of what to narrow down. 
  Typically it is an Ecto queryable, although it can also be a list of structs
  or any other custom data.

  The result should be a limited subset of the passed-in `scope`, or the `scope` itself
  if no limitations are required.
  """
  @callback scope(user :: term, resource :: module, scope :: any, params :: map) :: term
end