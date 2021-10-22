defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.

  Typically the callbacks are designed to be used by `Bodyguard.permit/4` and
  are not called directly.

  The only requirement is to implement the `c:authorize/3` callback:

      defmodule MyApp.MyContext do
        @behaviour Bodyguard.Policy

        def authorize(action, user, params) do
          # Return :ok or true to permit
          # Return :error, {:error, reason}, or false to deny
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

  If you want to define the callbacks in another module, you can use
  `defdelegate`:

      defmodule MyApp.MyContext do
        defdelegate authorize(action, user, params), to: Some.Other.Policy
      end

  """

  @type action :: atom | String.t()
  @type auth_result :: :ok | :error | {:error, reason :: any} | true | false

  @doc """
  Callback to authorize a user's action.

  To permit an action, return `:ok` or `true`. To deny, return `:error`,
  `{:error, reason}`, or `false`.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic relationship to a controller action, and instead should
  share a name with a particular function on the context.
  """
  @callback authorize(action :: action, user :: any, params :: %{atom => any} | any) ::
              auth_result

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Policy

      require Logger

      if policy = Keyword.get(opts, :policy) do
        Logger.debug(
          "DEPRECATION WARNING - #{inspect(__MODULE__)}: `use Bodyguard.Policy` is deprecated. Please use defdelegate instead, like this:\n\n    defdelegate authorize(action, user, params), to: #{inspect(policy)}\n"
        )

        defdelegate authorize(action, user, params), to: policy
      end
    end
  end
end
