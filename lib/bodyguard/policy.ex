defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.

  Typically the callbacks are designed to be used by `Bodyguard.permit/4` and
  are not called directly.

  The only requirement is to implement the `c:authorize/3` callback:

      defmodule MyApp.MyContext do
        @behaviour Bodyguard.Policy

        def authorize(action, user, params) do
          # Return :ok or {:error, reason}
        end
      end

  To perform authorization checks, use `Bodyguard.permit/4` and friends:

      with :ok <- Bodyguard.permit(MyApp.MyContext, :action_name, user, param: :value) do
        # ...
      end

      if Bodyguard.permit?(MyApp.MyContext, :action_name, user, param: :value) do
        # ...
      end

      Bodyguard.permit!(MyApp.MyContext, :action_name, user, param: :value)

  If you want to define the callbacks in another module, you can `use` this
  module and it will create a `c:authorize/3` callback wrapper for you:

      defmodule MyApp.MyContext do
        use Bodyguard.Policy, policy: Some.Other.Policy
      end

  """

  @type auth_result :: :ok | {:error, reason :: any}

  @doc """
  Callback to authorize a user's action.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic relationship to a controller action, and instead should
  share a name with a particular function on the context.

  To permit an action, return `:ok`. To deny, return `{:error, reason}`.
  """
  @callback authorize(action :: atom, user :: any, params :: %{atom => any}) :: auth_result

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Policy

      if policy = Keyword.get(opts, :policy) do
        def authorize(action, user, params \\ %{}) do
          unquote(policy).authorize(action, user, params)
        end
      end
    end
  end
end