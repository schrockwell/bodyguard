defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.

  The only requirement is to implement the `c:authorize/3` callback:

      defmodule MyApp.MyContext do
        use Bodyguard.Policy

        def authorize(user, action, params) do
          # Return :ok or {:error, reason}
        end
      end


  You can use the callback directly:

      with :ok <- MyApp.MyContext.authorize(user, :action_name, %{param: :value}) do
        # ...
      end

  Or use these convenience functions:

      if MyApp.MyContext.authorize?(user, :action_name, param: :value) do
        # ...
      end

      MyApp.MyContext.authorize!(user, :action_name, param: :value)
  """

  @doc false
  defmacro __using__(_) do
    quote do
      @behaviour Bodyguard.Policy

      def authorize!(user, action, params \\ %{}) do
        Bodyguard.Policy.authorize!(__MODULE__, user, action, params)
      end

      def authorize?(user, action, params \\ %{}) do
        Bodyguard.Policy.authorize?(__MODULE__, user, action, params)
      end
    end
  end

  @type params :: %{atom => any}
  @type auth_result :: :ok | {:error, reason :: any}
  @type opts :: keyword | params

  @doc """
  Authorize a user's action.

  Simply converts the `opts` to a `params` map and defers to the
  `c:authorize/3` callback on the specified `policy`.

  Returns `:ok` on success, and `{:error, reason}` on failure.
  """
  @spec authorize(policy :: module, user :: any, action :: atom, opts :: opts) :: auth_result
  def authorize(policy, user, action, opts \\ []) do
    params = Enum.into(opts, %{})
    apply(policy, :authorize, [user, action, params])
  end

  @doc """
  The same as `authorize/4`, but raises `Bodyguard.NotAuthorizedError` on
  authorization failure.

  Returns `:ok` on success.

  ## Options
  
  * `error_message` – a string to describe the error (default "not authorized")
  * `error_status` – the HTTP status code to raise with the error (default 403)

  The remaining `opts` are converted into a `params` map and passed to the
  `c:authorize/3` callback.
  """

  @spec authorize!(policy :: module, user :: any, action :: atom, opts :: opts) :: :ok
  def authorize!(policy, user, action, opts \\ []) do
    opts = Enum.into(opts, %{})
    {error_message, opts} = Map.pop(opts, :error_message, "not authorized")
    {error_status, opts} = Map.pop(opts, :error_status, 403)

    case authorize(policy, user, action, opts) do
      :ok -> :ok
      error -> raise Bodyguard.NotAuthorizedError, 
        message: error_message, status: error_status, reason: error
    end
  end

  @doc """
  The same as `authorize/4`, but returns a boolean.
  """
  @spec authorize?(policy :: module, user :: any, action :: atom, opts :: opts) :: boolean
  def authorize?(policy, user, action, opts \\ []) do
    case authorize(policy, user, action, opts) do
      :ok -> true
      _ -> false
    end
  end

  @doc """
  Callback to authorize a user's action.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic relationship to a controller action, and instead should
  share a name with a particular function on the context.

  To permit an action, return `:ok`. To deny, return `{:error, reason}`.
  """
  @callback authorize(user :: any, action :: atom, params :: params) :: auth_result
end