defmodule PolicyTest do
  use ExUnit.Case, async: true

  setup do
    %{context: TestContext, user: %TestContext.User{}}
  end

  test "authorizing behaviour directly", %{context: context, user: user} do
    assert :ok                      = context.authorize(:action, user)
    assert {:error, :unauthorized}  = context.authorize(:fail, user)
    assert {:error, %{key: :value}} = context.authorize(:fail_with_params, user, %{key: :value})
  end

  test "authorizing via helper", %{context: context, user: user} do
    assert :ok                      = Bodyguard.permit(context, :action, user)
    assert {:error, :unauthorized}  = Bodyguard.permit(context, :fail, user)
    assert {:error, %{key: :value}} = Bodyguard.permit(context, :fail_with_params, user, %{key: :value})
    assert {:error, %{key: :value}} = Bodyguard.permit(context, :fail_with_params, user, key: :value)
  end

  test "authorizing via boolean helper", %{context: context, user: user} do
    assert Bodyguard.permit?(context, :action, user)
    refute Bodyguard.permit?(context, :fail, user)
  end

  test "authorizing via bangin' helpers", %{context: context, user: user} do
    assert :ok = Bodyguard.permit!(context, :action, user)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Bodyguard.permit!(context, :fail, user)
    end

    custom_error = assert_raise Bodyguard.NotAuthorizedError, fn ->
      Bodyguard.permit!(context, :fail, user, error_message: "whoops", error_status: 500)
    end
    assert %{message: "whoops", status: 500} = custom_error
  end

  test "specifying a separate policy", %{user: user} do
    assert :ok                     = TestDeferralContext.authorize(:succeed, user)
    assert {:error, :unauthorized} = TestDeferralContext.authorize(:fail, user)
  end

  test "implicit authorization with defauth" do
    context = TestDefauthContext
    user = %TestDefauthContext.User{allow: true}

    assert :succeed = context.succeed(user)
    assert :override = context.succeed(user, :override)
    assert :result = context.succeed(user, %{result: :result})
    assert :var2 = context.succeed(user, :var1, :var2, :var3)
    assert :var2 = context.succeed(user, :var1, %{var2: :var2}, :var3)
    assert {:error, :unauthorized} = context.fail(user, %{})
  end

  test "testability skipping auth" do
    context = TestDefauthContext

    assert :succeed = context.__succeed__()
    assert :override = context.__succeed__(:override)
    assert :result = context.__succeed__(%{result: :result})
    assert :var2 = context.__succeed__(:var1, :var2, :var3)
    assert :var2 = context.__succeed__(:var1, %{var2: :var2}, :var3)
    assert :fail = context.__fail__(%{})
  end

  test "implicit authorization with defauth and deferral policy" do
    context = TestDefauthDeferralContext
    user = %TestDefauthDeferralContext.User{allow: true}

    assert :succeed = context.succeed(user)
    assert :override = context.succeed(user, :override)
    assert :result = context.succeed(user, %{result: :result})
    assert :var2 = context.succeed(user, :var1, :var2, :var3)
    assert :var2 = context.succeed(user, :var1, %{var2: :var2}, :var3)
    assert {:error, :unauthorized} = context.fail(user, %{})
  end
end
