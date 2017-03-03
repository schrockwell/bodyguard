defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.
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
      def scope(actor, action, scope, opts \\ []) do
        Bodyguard.scope(__MODULE__, actor, action, scope, opts)
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
  Callback to authorize a user's action.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic mapping to a controller "action".

  To permit an action, return `:ok`.

  To deny authorization, return `{:error, reason}`.
  """
  @callback permit(user :: any, action :: atom, params :: map) 
    :: :ok | {:error, reason :: atom}

  @doc """
  Callback to limit which resources a user can access.

  The `scope` argument is a broad specification of what to narrow down.
  Typically it is an Ecto queryable, although it can also be a list or any
  other custom data.

  The result should be a limited subset of the passed-in `scope`, or the `scope` itself
  if no limitations are required.
  """
  @callback filter(user :: term, action :: atom, scope :: any, params :: map) :: term

  @doc """
  Injected function to perform authorization.

  See `Bodyguard.authorize/4` for details.
  """
  @callback authorize(actor :: any, action :: atom, opts :: map)
    :: :ok | {:error, reason :: atom}

  @doc """
  Injected function to perform authorization.

  See `Bodyguard.authorize!/4` for details.
  """
  @callback authorize!(actor :: any, action :: atom, opts :: map) :: :ok

  @doc """
  Injected function to perform authorization.

  See `Bodyguard.authorize?/4` for details.
  """
  @callback authorize?(actor :: any, action :: atom, opts :: map) :: boolean

  @doc """
  Injected function to perform scoping.

  See `Bodyguard.scope/5` for details.
  """
  @callback scope(actor :: any, action :: atom, scope :: any, opts :: keyword) :: any


  @doc """
  Injected function to perform authorization on a Plug.Conn.

  See `Bodyguard.Conn.authorize/4` for details.
  """
  @callback authorize_conn(conn :: Plug.Conn.t, action :: atom, opts :: map)
    :: :ok | {:error, reason :: atom}

  @doc """
  Injected function to perform authorization on a Plug.Conn.

  See `Bodyguard.Conn.authorize!/4` for details.
  """
  @callback authorize_conn!(conn :: Plug.Conn.t, action :: atom, opts :: map) :: :ok
end