defmodule TestContext do
  use Bodyguard.Policy

  defmodule User do
    defstruct [allow: true]
  end

  def authorize(action, user, params \\ %{})

  def authorize(_, %User{allow: false}, _params) do
    {:error, :unauthorized}
  end

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

defmodule TestDefauthContext do
  use Bodyguard.Policy

  defmodule User do
    defstruct [allow: true]
  end

  def authorize(action, user, params \\ %{})

  # mapify params, and send to the authorize method
  def authorize(:fail, _user, _params) do
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: true}, %{var2: :var2}) do
    IO.inspect "var2 = var2"
    :ok
  end
  def authorize(_, %User{allow: true}, %{var2: %{var2: :var2}}) do
    IO.inspect "var2 = var2"
    :ok
  end

  def authorize(_, %User{allow: true}, %{var2: _}) do
    IO.inspect "var2 != var2"
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: false}, _params) do
    IO.inspect "User allow false"
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: true}, _params) do
    IO.inspect "User allow true"
    :ok
  end

  def authorize(_action, _user, _params) do
    {:error, :unauthorized}
  end

  defauth fail(_params) do
    :fail
  end

  defauth succeed(%{result: result}) do
    result
  end

  defauth succeed(result \\ :succeed) do
    result
  end

  defauth succeed(_var1, %{var2: var2}, _var3) do
    var2
  end

  defauth succeed(_var1, var2, _var3) do
    var2
  end

end

defmodule TestDefauthDeferralContext do
  use Bodyguard.Policy, policy: TestDefauthDeferralContext.Policy

  defmodule User do
    defstruct [allow: true]
  end

  defauth fail(_params) do
    :fail
  end

  defauth succeed(%{result: result}) do
    result
  end

  defauth succeed(result \\ :succeed) do
    result
  end

  defauth succeed(_var1, %{var2: var2}, _var3) do
    var2
  end

  defauth succeed(_var1, var2, _var3) do
    var2
  end
end

defmodule TestDefauthDeferralContext.Policy do
  alias TestDefauthDeferralContext.User

  def authorize(action, user, params \\ %{})

  # mapify params, and send to the authorize method
  def authorize(:fail, _user, _params) do
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: true}, %{var2: :var2}) do
    IO.inspect "var2 = var2"
    :ok
  end
  def authorize(_, %User{allow: true}, %{var2: %{var2: :var2}}) do
    IO.inspect "var2 = var2"
    :ok
  end

  def authorize(_, %User{allow: true}, %{var2: _}) do
    IO.inspect "var2 != var2"
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: false}, _params) do
    IO.inspect "User allow false"
    {:error, :unauthorized}
  end

  def authorize(_, %User{allow: true}, _params) do
    IO.inspect "User allow true"
    :ok
  end

  def authorize(_action, _user, _params) do
    {:error, :unauthorized}
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
