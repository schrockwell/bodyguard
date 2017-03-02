defmodule BodyguardTest do
  alias BodyguardTest.{Context, User, Resource}

  use ExUnit.Case, async: true
  doctest Bodyguard

  defmodule User do
    defstruct [auth_result: :ok, auth_scope: :new_scope]
  end

  defmodule Resource do
    defstruct []
  end

  defmodule Context do
    defmodule Policy do
      use Bodyguard.Policy

      def permit(%User{auth_result: result}, _action, _params), do: result

      def filter(%User{auth_scope: nil}, Resource, scope, _params), do: scope
      def filter(%User{auth_scope: scope}, Resource, _scope, _params), do: scope
    end

    defmodule OtherPolicy do
      use Bodyguard.Policy

      def permit(_user, :return_params, params), do: {:error, params}
      def permit(_user, _action, _params), do: {:error, :other_result}

      def filter(_user, Resource, _scope, _params), do: :other_scope
    end
  end

  defmodule ResourceController do
    def action(conn, _params) do
      with :ok <- Context.Policy.authorize(conn, :access) do
        conn
      end
    end

    def return_params_action(conn, _params) do
      with :ok <- Context.OtherPolicy.authorize(conn, :return_params) do
        conn
      end
    end

    def action!(conn, _params) do
      Context.Policy.authorize!(conn, :access)
      conn
    end
  end

  defmodule FallbackController do
    def call(conn, {:error, _reason}), do: conn
  end

  test "basic authorization" do
    results = [
      {:ok, true},
      {{:error, :unauthorized}, false},
      {{:error, :not_found}, false}
    ]

    for {result, boolean} <- results do
      # Standard auth
      assert Context.Policy.authorize(%User{auth_result: result}, :access) == result

      # Boolean auth
      assert Context.Policy.authorize?(%User{auth_result: result}, :access) == boolean

      # Error auth
      if boolean do
        assert Context.Policy.authorize!(%User{auth_result: result}, :access) == :ok
      else
        assert_raise Bodyguard.NotAuthorizedError, fn ->
          Context.Policy.authorize!(%User{auth_result: result}, :access)
        end
      end
    end
  end

  test "overriding the error defaults" do
    exception = assert_raise Bodyguard.NotAuthorizedError, fn ->
      Context.Policy.authorize!(%User{auth_result: {:error, :foo}}, :access, error_message: "whoops", error_status: 404)
    end

    assert exception.message == "whoops"
    assert exception.status == 404
  end

  test "basic scope limiting" do
    assert Context.Policy.scope(%User{auth_scope: nil}, Resource) == Resource

    # Test type resolution
    assert Context.Policy.scope(%User{auth_scope: :limited}, Resource) == :limited
    assert Context.Policy.scope(%User{auth_scope: :limited}, %Resource{}) == :limited
    assert Context.Policy.scope(%User{auth_scope: :limited}, [%Resource{}]) == :limited
    # TODO: Check Ecto.Query
    assert_raise ArgumentError, fn ->
      Context.Policy.scope(%User{auth_scope: :limited}, %{}) # Can't determine type of %{}
    end

  end

  test "current user using a function" do
    defmodule TestLoader do
      def current_resource(_actor), do: %User{auth_result: {:error, :custom_user}}
    end

    # Set config
    Application.put_env(:bodyguard, :resolve_user, {TestLoader, :current_resource})

    # Use custom loader
    assert Bodyguard.resolve_user(:actor) == %User{auth_result: {:error, :custom_user}}
    assert Context.Policy.authorize(:actor, :access) == {:error, :custom_user}

    # Reset config
    Application.delete_env(:bodyguard, :resolve_user)
  end

  test "setting default options via a plug" do
    alias Bodyguard.Plug.PutOptions

    conn = Plug.Test.conn(:get, "/")

    # Set options
    conn = PutOptions.call(conn, PutOptions.init(param: :value))

    # Use them in controller actions
    assert ResourceController.return_params_action(conn, %{}) == {:error, %{param: :value}}
  end

  test "authorizing via a plug" do
    alias Bodyguard.Plug.Authorize
    conn = Plug.Test.conn(:get, "/") |> Plug.Conn.assign(:current_user, %User{})
    
    # Success
    assert %Plug.Conn{} = Authorize.call(conn, Authorize.init(policy: Context.Policy, action: :access))

    # Failure (raise)
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      Authorize.call(conn, Authorize.init(policy: Context.OtherPolicy, action: :access))
    end

    # Failure (fallback recovery)
    assert %Plug.Conn{} = Authorize.call(conn, Authorize.init(policy:
      Context.OtherPolicy, action: :access, fallback: FallbackController))
  end

  test "verifying authorization via a plug" do
    alias Bodyguard.Plug.VerifyAuthorizedAfter

    conn = Plug.Test.conn(:get, "/") |> Plug.Conn.assign(:current_user, %User{})

    # Raising when no authorization performed
    assert_raise Bodyguard.NotAuthorizedError, fn ->
      conn
      |> VerifyAuthorizedAfter.call(VerifyAuthorizedAfter.init)
      |> Plug.Conn.send_resp(200, "")
    end

    # Using fallback when no authorization performed
    assert %Plug.Conn{} =
      conn
      |> VerifyAuthorizedAfter.call(VerifyAuthorizedAfter.init(fallback: FallbackController))
      |> Plug.Conn.send_resp(200, "")

    # OK when manually marked as authorized
    assert %Plug.Conn{} =
      conn
      |> Bodyguard.Conn.mark_authorized
      |> VerifyAuthorizedAfter.call(VerifyAuthorizedAfter.init)
      |> Plug.Conn.send_resp(200, "")

    # OK when authorization checked
    assert {:ok, authorized_conn} = Context.Policy.authorize_conn(conn, :access)
    assert %Plug.Conn{} = 
      authorized_conn
      |> VerifyAuthorizedAfter.call(VerifyAuthorizedAfter.init)
      |> Plug.Conn.send_resp(200, "")

    assert %Plug.Conn{} =
      conn
      |> Context.Policy.authorize_conn!(:access)
      |> VerifyAuthorizedAfter.call(VerifyAuthorizedAfter.init)
      |> Plug.Conn.send_resp(200, "")

    assert {:error, _} = Bodyguard.Conn.authorize(conn, Context.OtherPolicy, :access)
  end
end
