defmodule TestContext do
  @behaviour Bodyguard.Policy

  defmodule User do
    defstruct allow: true
  end

  def authorize(action, user, params \\ %{})

  def authorize(_, %User{allow: false}, _params) do
    {:error, :unauthorized}
  end

  def authorize(:param_fun_fail, _, %{"id" => id}) do
    id != 1
  end

  def authorize(:param_fun_pass, _, %{"id" => id}) do
    id == 1
  end

  def authorize(:fail_with_params, _user, params) do
    {:error, params}
  end

  def authorize(:fail, _user, _params) do
    {:error, :unauthorized}
  end

  def authorize(:ok_boolean, _user, _params) do
    true
  end

  def authorize(:fail_boolean, _user, _params) do
    false
  end

  def authorize(:error_boolean, _user, _params) do
    :error
  end

  def authorize(_action, _user, _params) do
    :ok
  end
end

defmodule TestDeferralContext do
  use Bodyguard.Policy, policy: TestDeferralContext.Policy
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
