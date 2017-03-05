defmodule PolicyTest do
  use ExUnit.Case, async: true

  alias Bodyguard.Policy

  setup do
    %{context: TestContext, user: %TestContext.User{}}
  end

  test "authorizing behaviour directly", %{context: context, user: user} do
    assert :ok = context.authorize(user, :action)
    assert {:error, :unauthorized} = context.authorize(user, :fail)
    assert {:error, %{key: :value}} = context.authorize(user, :fail_with_params, %{key: :value})
  end

  test "authorizing via helper", %{context: context, user: user} do
    assert :ok = Policy.authorize(context, user, :action)
    assert {:error, :unauthorized} = Policy.authorize(context, user, :fail)
    assert {:error, %{key: :value}} = Policy.authorize(context, user, :fail_with_params, %{key: :value})
    assert {:error, %{key: :value}} = Policy.authorize(context, user, :fail_with_params, key: :value)
  end

  test "authorizing booleans via helper", %{context: context, user: user} do
    assert Policy.authorize?(context, user, :action)
    refute Policy.authorize?(context, user, :fail)
  end

  test "authorizing via bangin' helpers", %{context: context, user: user} do
    assert :ok = Policy.authorize!(context, user, :action)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Policy.authorize!(context, user, :fail)
    end

    custom_error = assert_raise Bodyguard.NotAuthorizedError, fn ->
      Policy.authorize!(context, user, :fail, error_message: "whoops", error_status: 500)
    end
    assert %{message: "whoops", status: 500} = custom_error
  end
end