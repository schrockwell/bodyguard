defmodule PlugTest do
  use ExUnit.Case, async: true
  import Bodyguard.Action
  alias Bodyguard.Action

  setup do
    conn = 
      Plug.Test.conn(:get, "/")
      # |> Plug.Conn.assign(:action, :test)

    {:ok, conn: conn}
  end

  def build_action(conn) do
    opts = Bodyguard.Plug.BuildAction.init(context: TestContext, policy: TestDeferralContext.Policy)
    Bodyguard.Plug.BuildAction.call(conn, opts)
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

  test "Authorize plug with raising", %{conn: conn} do
    conn = build_action(conn)

    # Failure
    opts = Bodyguard.Plug.Authorize.init(name: :fail)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Bodyguard.Plug.Authorize.call(conn, opts)
    end

    # Success
    opts = Bodyguard.Plug.Authorize.init(name: :succeed)
    assert Bodyguard.Plug.Authorize.call(conn, opts)
  end

  test "Authorize plug with fallback", %{conn: conn} do
    conn = build_action(conn)
    
    # Failure
    opts      = Bodyguard.Plug.Authorize.init(name: :fail, fallback: TestFallbackController)
    fail_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    assert fail_conn.assigns[:fallback_handled]
    refute fail_conn.assigns.action.authorized?

    # Success
    opts    = Bodyguard.Plug.Authorize.init(name: :succeed, fallback: TestFallbackController)
    ok_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    refute ok_conn.assigns[:fallback_handled]
    assert ok_conn.assigns.action.authorized?
  end

  test "Authorize plug and continue", %{conn: conn} do
    conn = build_action(conn)
    
    # Failure
    opts      = Bodyguard.Plug.Authorize.init(name: :fail, raise: false)
    fail_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    refute fail_conn.assigns[:fallback_handled]
    refute fail_conn.assigns.action.authorized?

    # Success
    opts    = Bodyguard.Plug.Authorize.init(name: :succeed, raise: false)
    ok_conn = Bodyguard.Plug.Authorize.call(conn, opts)

    refute ok_conn.assigns[:fallback_handled]
    assert ok_conn.assigns.action.authorized?
  end
end