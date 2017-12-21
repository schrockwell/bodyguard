defmodule PlugTest do
  use ExUnit.Case, async: true
  import Bodyguard.Action
  alias Bodyguard.Action

  setup do
    conn = Plug.Test.conn(:get, "/")
    allow_user = %TestContext.User{allow: true}
    deny_user = %TestContext.User{allow: false}
    {:ok, conn: conn, allow_user: allow_user, deny_user: deny_user}
  end

  def build_action(conn, opts \\ []) do
    opts = Keyword.merge([context: TestContext, policy: TestDeferralContext.Policy], opts)
    plug_opts = Bodyguard.Plug.BuildAction.init(opts)
    Bodyguard.Plug.BuildAction.call(conn, plug_opts)
  end

  test "putting an updating an action", %{conn: conn} do
    conn = Bodyguard.Plug.put_action(conn, act(TestContext))
    assert %Action{} = conn.assigns.action

    conn = Bodyguard.Plug.update_action(conn, &put_user(&1, %TestContext.User{}))
    assert %Action{user: %TestContext.User{}} = conn.assigns.action
  end

  test "BuildAction plug", %{conn: conn} do
    conn = build_action(conn)
    assert %Action{context: TestContext, policy: TestDeferralContext.Policy} = conn.assigns.action
  end

  test "BuildAction plug with a custom key", %{conn: conn} do
    conn = build_action(conn, key: :custom_action)

    assert %Action{context: TestContext, policy: TestDeferralContext.Policy} =
             conn.assigns.custom_action
  end

  test "Authorize plug with raising", %{conn: conn, allow_user: allow_user, deny_user: deny_user} do
    # Failure
    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: :any,
        user: fn _ -> deny_user end
      )

    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Bodyguard.Plug.Authorize.call(conn, opts)
    end

    # Success
    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: :any,
        user: fn _ -> allow_user end
      )

    assert Bodyguard.Plug.Authorize.call(conn, opts)
  end

  test "Authorize plug with fallback", %{conn: conn, allow_user: allow_user, deny_user: deny_user} do
    conn = build_action(conn)

    # Failure
    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: :any,
        user: fn _ -> deny_user end,
        fallback: TestFallbackController
      )

    fail_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    assert fail_conn.assigns[:fallback_handled]
    assert fail_conn.halted

    # Success
    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: :any,
        user: fn _ -> allow_user end,
        fallback: TestFallbackController
      )

    ok_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    refute ok_conn.assigns[:fallback_handled]
    refute ok_conn.halted
  end

  test "Authorize plug with a custom action function", %{conn: conn, allow_user: allow_user} do
    conn = Plug.Conn.assign(conn, :user, allow_user)
    conn = Plug.Conn.assign(conn, :action, :any)

    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: & &1.assigns.action,
        user: & &1.assigns.user
      )

    assert Bodyguard.Plug.Authorize.call(conn, opts)

    conn = Plug.Conn.assign(conn, :action, :fail)

    opts =
      Bodyguard.Plug.Authorize.init(
        policy: TestContext,
        action: & &1.assigns.action,
        user: & &1.assigns.user
      )

    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Bodyguard.Plug.Authorize.call(conn, opts)
    end
  end
end
