defmodule PolicyTest do
  use ExUnit.Case, async: true

  alias Bodyguard.Policy

  setup do
    %{context: TestContext, user: %TestContext.User{}}
  end

  test "authorizing behaviour directly", %{context: context, user: user} do
    assert :ok = context.authorize(:action, user)
    assert {:error, :unauthorized} = context.authorize(:fail, user)
    assert {:error, %{key: :value}} = context.authorize(:fail_with_params, user, %{key: :value})
  end

  test "authorizing via helper", %{context: context, user: user} do
    assert :ok = Policy.authorize(context, :action, user)
    assert {:error, :unauthorized} = Policy.authorize(context, :fail, user)
    assert {:error, %{key: :value}} = Policy.authorize(context, :fail_with_params, user, %{key: :value})
    assert {:error, %{key: :value}} = Policy.authorize(context, :fail_with_params, user, key: :value)
  end

  test "authorizing via boolean helper", %{context: context, user: user} do
    assert Policy.authorize?(context, :action, user)
    refute Policy.authorize?(context, :fail, user)
  end

  test "authorizing via injected boolean", %{context: context, user: user} do
    assert context.authorize?(:action, user)
    refute context.authorize?(:fail, user)
  end

  test "authorizing via bangin' helpers", %{context: context, user: user} do
    assert :ok = Policy.authorize!(context, :action, user)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Policy.authorize!(context, :fail, user)
    end

    custom_error = assert_raise Bodyguard.NotAuthorizedError, fn ->
      Policy.authorize!(context, :fail, user, error_message: "whoops", error_status: 500)
    end
    assert %{message: "whoops", status: 500} = custom_error
  end

  test "authorizing via injected bang!", %{context: context, user: user} do
    assert :ok = context.authorize!(:action, user)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      context.authorize!(:fail, user)
    end

    custom_error = assert_raise Bodyguard.NotAuthorizedError, fn ->
      context.authorize!(:fail, user, error_message: "whoops", error_status: 500)
    end
    assert %{message: "whoops", status: 500} = custom_error
  end
end