defmodule Policy.HelpersTest do
  use ExUnit.Case

  defmodule MockStruct do
    defstruct permit: false
  end

  defmodule MockStruct.Policy do
    def can?(_user, :test, model), do: model.permit
  end

  defmodule MockStruct.CustomErrorPolicy do
    def can?(_user, _action, _model), do: {:error, :because_i_said_so}
  end

  defmodule MockStruct.PermitNilPolicy do
    def can?(_user, _action, nil), do: true
  end

  defmodule MockStruct.DenyNilPolicy do
    def can?(_user, _action, nil), do: false
  end

  setup do
    conn = Plug.Test.conn(:get, "/") |> Plug.Conn.assign(:action, :test)

    {:ok, conn: conn}
  end

  test "authorizing a nonpermitted action raises an exception", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, %MockStruct{permit: false})
      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 403
        assert exception.message == "not authorized"
        assert exception.reason == :unauthorized
    end
  end

  test "authorizing a nonpermitted action with a custom error status raises an exception", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, %MockStruct{permit: false}, error_status: 404)
      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 404
        assert exception.message == "not authorized"
        assert exception.reason == :unauthorized
    end
  end

  test "authorizing a permitted action does not raise an exception", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, %MockStruct{permit: true})
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "failing to authorize after verifying it is authorized is run raises an exception", %{conn: conn} do
    try do
      conn
      |> Bodyguard.Controller.verify_authorized
      |> Plug.Conn.send_resp(200, "Hello, World!")

      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 403
        assert exception.message == "no authorization run"
        assert exception.reason == :no_authorization_run
    end
  end

  test "authorizing a permitted action after verifying it is authorized does not raise an exception", %{conn: conn} do
    try do
      conn
      |> Bodyguard.Controller.verify_authorized
      |> Bodyguard.Controller.authorize!(%MockStruct{permit: true})
      |> Plug.Conn.send_resp(200, "Hello, World!")
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "marking authorized after verifying it is authorized does not raise an exception", %{conn: conn} do
    try do
      conn
      |> Bodyguard.Controller.verify_authorized
      |> Bodyguard.Controller.mark_authorized
      |> Plug.Conn.send_resp(200, "Hello, World!")
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "authorizing a nil model raises an exception", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, nil)
      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 403
        assert exception.message == "not authorized"
        assert exception.reason == :unauthorized
    end
  end

  test "authorizing a nil model with an explicit permit policy", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, nil, policy: MockStruct.PermitNilPolicy)
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "authorizing a nil model with an explicit deny policy", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, nil, policy: MockStruct.DenyNilPolicy)
      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 403
        assert exception.message == "not authorized"
        assert exception.reason == :unauthorized
    end
  end

  test "authorization with a custom error reason", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, nil, policy: MockStruct.CustomErrorPolicy)
      flunk "exception not raised"
    rescue
      exception in Bodyguard.NotAuthorizedError ->
        assert Plug.Exception.status(exception) == 403
        assert exception.message == "not authorized"
        assert exception.reason == :because_i_said_so
    end
  end

  test "view helpers", %{conn: conn} do
    # Plug.Conn as first argument
    assert Bodyguard.ViewHelpers.can?(conn, :test, %MockStruct{permit: true})
    refute Bodyguard.ViewHelpers.can?(conn, :test, %MockStruct{permit: false})

    # User as first argument
    assert Bodyguard.ViewHelpers.can?(:some_user, :test, %MockStruct{permit: true})
    refute Bodyguard.ViewHelpers.can?(:some_user, :test, %MockStruct{permit: false})
  end

  test "default options plug", %{conn: conn} do
    # Basic case
    struct = %MockStruct{permit: true}
    assert Bodyguard.Controller.authorize(conn, struct)

    # Now set a default on this conn, like a plug would do
    conn = Bodyguard.Controller.put_bodyguard_options(conn, policy: MockStruct.CustomErrorPolicy)

    # Check that the default works, and can still be overridden
    assert Bodyguard.Controller.authorize(conn, struct) == {:error, :because_i_said_so}
    assert Bodyguard.Controller.authorize(conn, struct, policy: MockStruct.Policy)
  end

  test "current user from keyword", %{conn: conn} do
    Application.put_env(:bodyguard, :current_user, :bodyguard_test_user)

    user = %{name: "test-user"}
    conn = Plug.Conn.assign(conn, :bodyguard_test_user, user)
    assert Bodyguard.Controller.get_current_user(conn) == user
  end

  test "current user using a function", %{conn: conn} do
    defmodule TestLoader do
      def current_resource(conn) do
        conn.private[:bodyguard_test_user]
      end
    end
    Application.put_env(:bodyguard, :current_user, {TestLoader, :current_resource})

    user = %{name: "test-user"}
    conn = Plug.Conn.put_private(conn, :bodyguard_test_user, user)
    assert Bodyguard.Controller.get_current_user(conn) == user
  end
end
