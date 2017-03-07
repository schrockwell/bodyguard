defmodule TestContext do
  use Bodyguard.Context

  defmodule User do
    defstruct []
  end
  
  def authorize(_user, _action, params \\ %{})
  def authorize(_user, :fail_with_params, params) do
    {:error, params}
  end

  def authorize(_user, :fail, _params) do
    {:error, :unauthorized}
  end

  def authorize(_user, _action, _params) do
    :ok
  end
end

ExUnit.start()
