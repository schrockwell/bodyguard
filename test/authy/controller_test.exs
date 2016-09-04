defmodule Policy.HelpersTest do
  use ExUnit.Case

  defmodule MockStruct do
    defstruct permit: false
  end

  defmodule MockStruct.Policy do
    def can?(_user, :test, model), do: model.permit
  end

  setup do
    conn = Plug.Test.conn(:get, "/") |> Plug.Conn.assign(:action, :test)

    {:ok, conn: conn}
  end

  test "authorizing a nonpermitted action raises an exception", %{conn: conn} do
    assert_raise Authy.NotAuthorizedError, fn ->
      Authy.Controller.authorize!(conn, %MockStruct{permit: false})
    end
  end

  test "authorizing a permitted action does not raise an exception", %{conn: conn} do
    try do
      Authy.Controller.authorize!(conn, %MockStruct{permit: true})
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "failing to authorize after verifying it is authorized is run raises an exception", %{conn: conn} do
    assert_raise Authy.NotAuthorizedError, fn ->
      conn
      |> Authy.Controller.verify_authorized
      |> Plug.Conn.send_resp(200, "Hello, World!")
    end
  end

  test "authorizing a permitted action after verifying it is authorized does not raise an exception", %{conn: conn} do
    try do
      conn
      |> Authy.Controller.verify_authorized
      |> Authy.Controller.authorize!(%MockStruct{permit: true})
      |> Plug.Conn.send_resp(200, "Hello, World!")
    rescue _e ->
      flunk "exception raised"
    end
  end

  test "marking authorized after verifying it is authorized does not raise an exception", %{conn: conn} do
    try do
      conn
      |> Authy.Controller.verify_authorized
      |> Authy.Controller.mark_authorized
      |> Plug.Conn.send_resp(200, "Hello, World!")
    rescue _e ->
      flunk "exception raised"
    end
  end
end
