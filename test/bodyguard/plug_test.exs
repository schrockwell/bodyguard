defmodule PlugTest do
  use ExUnit.Case, async: false
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

  def get_action(conn), do: conn.assigns.action
  def get_user(conn), do: conn.assigns.user
  def get_params(conn), do: conn.assigns.params

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

    inits = [
      # function/1 variant
      [policy: TestContext, action: & &1.assigns.action, user: & &1.assigns.user],

      # {module, fun} variant
      [policy: TestContext, action: {__MODULE__, :get_action}, user: {__MODULE__, :get_user}]
    ]

    for init <- inits do
      opts = Bodyguard.Plug.Authorize.init(init)
      assert Bodyguard.Plug.Authorize.call(conn, opts)
    end

    conn = Plug.Conn.assign(conn, :action, :fail)

    for init <- inits do
      opts = Bodyguard.Plug.Authorize.init(init)

      assert_raise Bodyguard.NotAuthorizedError, fn ->
        Bodyguard.Plug.Authorize.call(conn, opts)
      end
    end
  end

  test "Authorize plug with a custom params function", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.assign(:params, %{"id" => 1})
      |> Plug.Conn.assign(:action, :param_fun_pass)

    inits = [
      [policy: TestContext, action: & &1.assigns.action, params: & &1.assigns.params],
      [policy: TestContext, action: {__MODULE__, :get_action}, params: {__MODULE__, :get_params}]
    ]

    for init <- inits do
      opts = Bodyguard.Plug.Authorize.init(init)
      assert Bodyguard.Plug.Authorize.call(conn, opts)
    end

    conn = Plug.Conn.assign(conn, :action, :param_fun_fail)

    for init <- inits do
      opts = Bodyguard.Plug.Authorize.init(init)

      assert_raise Bodyguard.NotAuthorizedError, fn ->
        Bodyguard.Plug.Authorize.call(conn, opts)
      end
    end
  end

  test "Authorize plug with default options", %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.assign(:params, %{"id" => 1})
      |> Plug.Conn.assign(:action, :any)

    Application.put_env(:bodyguard, Bodyguard.Plug.Authorize,
      action: {__MODULE__, :get_action},
      params: {__MODULE__, :get_params}
    )

    opts = Bodyguard.Plug.Authorize.init(policy: TestContext)
    assert Bodyguard.Plug.Authorize.call(conn, opts)

    Application.delete_env(:bodyguard, Bodyguard.Plug.Authorize)
  end
end
