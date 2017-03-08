defmodule TestContext do
  use Bodyguard.Context

  defmodule User do
    defstruct []
  end
  
  def authorize(action, user, params \\ %{})
  def authorize(:fail_with_params, _user, params) do
    {:error, params}
  end

  def authorize(:fail, _user, _params) do
    {:error, :unauthorized}
  end

  def authorize(_action, _user, _params) do
    :ok
  end
end

defmodule TestDeferralContext do
  use Bodyguard.Context, policy: TestDeferralContext.Policy
end

defmodule TestDeferralContext.Policy do
  def authorize(action, user, params \\ %{})
  def authorize(:fail, _user, _params), do: {:error, :unauthorized}
  def authorize(:succeed, _user, _params), do: :ok
end

defmodule TestFallbackController do
  def call(conn, {:error, _reason}) do
    Plug.Conn.assign(conn, :fallback_handled, true)
  end
end

ExUnit.start()
