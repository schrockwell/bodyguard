defmodule TestContext do
  use Bodyguard.Context

  defmodule User do
    defstruct []
  end
  
  def authorize(_action, _user, params \\ %{})
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

ExUnit.start()
