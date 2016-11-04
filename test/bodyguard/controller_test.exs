defmodule Policy.HelpersTest do
  use ExUnit.Case

  defmodule MockStruct do
    defstruct permit: false
  end

  defmodule MockStruct.Policy do
    def can?(_user, :test, model), do: model.permit
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
    rescue exception ->
      assert Plug.Exception.status(exception) == 403
      assert exception.message == "not authorized"
    end
  end

  test "authorizing a nonpermitted action with a custom error status raises an exception", %{conn: conn} do
    try do
      Bodyguard.Controller.authorize!(conn, %MockStruct{permit: false}, error_status: 404)
      flunk "exception not raised"
    rescue exception ->
      assert Plug.Exception.status(exception) == 404
      assert exception.message == "not authorized"
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
    rescue exception ->
      assert Plug.Exception.status(exception) == 403
      assert exception.message == "no authorization run"
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
    rescue exception ->
      assert Plug.Exception.status(exception) == 403
      assert exception.message == "not authorized"
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
    rescue exception ->
      assert Plug.Exception.status(exception) == 403
      assert exception.message == "not authorized"
    end
  end
end
