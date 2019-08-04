defmodule ActionTest do
  use ExUnit.Case, async: false

  import Bodyguard.Action
  alias Bodyguard.Action

  test "authorizing a basic action" do
    result =
      act(TestContext)
      |> permit(:some_action)
      |> run(fn _ -> :done end)

    assert result == :done
  end

  test "action assigns" do
    action = assign(%Action{}, :key, :value)
    assert action.assigns.key == :value
  end

  test "force authorization" do
    result =
      act(TestContext)
      |> force_authorized()
      |> run(fn _ -> :done end)

    assert result == :done
  end

  test "force deny authorization" do
    result =
      act(TestContext)
      |> permit(:some_action)
      |> force_unauthorized({:error, :forced})
      |> run(fn _ -> :done end)

    assert result == {:error, :forced}
  end

  test "merging in assigns to params" do
    result =
      act(TestContext)
      |> assign(:assign, :foo)
      |> assign(:other_assign, :moo)
      |> permit(:fail_with_params, param: :bar, other_assign: :derp)
      |> run(fn _ -> :done end)

    assert {:error, %{assign: :foo, other_assign: :derp, param: :bar}} = result
  end

  test "fallbacks" do
    action = act(TestContext)

    result =
      action
      |> put_fallback(fn _ -> :fallback end)
      |> permit(:fail)
      |> run(fn _ -> :done end)

    assert result == :fallback

    result =
      action
      |> permit(:fail)
      |> run(fn _ -> :done end, fn _ -> :fallback end)

    assert result == :fallback
  end

  test "bang methods!" do
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      act(TestContext)
      |> permit(:fail)
      |> run!(fn _ -> :done end)
    end
  end
end
