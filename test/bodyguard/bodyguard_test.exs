defmodule BodyguardTest do
  import Bodyguard
  alias BodyguardTest.Post
  alias BodyguardTest.User

  use ExUnit.Case, async: true
  doctest Bodyguard

  defmodule User do
    defstruct [id: nil, role: :guest]
  end

  defmodule Post do
    defstruct [user_id: nil]

    defmodule Policy do
      def can?(%User{role: :admin}, _action, _post), do: true
      def can?(_user, :index, _post), do: true
      def can?(nil, _action, _post), do: false
      def can?(%User{id: id}, :edit, %Post{user_id: user_id}) when user_id == id, do: true
      def can?(_user, :show, _post), do: true
      def can?(_, _, _), do: false

      def scope(_user, :index, _opts), do: :all_posts_scope
      def scope(user, _action, _opts) do
        case user do
          %{role: :admin}
            -> :admin_posts_scope
          _
            -> :guest_posts_scope
        end
      end
    end
  end

  defmodule PostController do
    import Bodyguard.Controller

    def index(conn, _params) do
      with {:ok, conn} <- authorize(conn, Post) do
        scope(conn, Post)
      end
    end

    def edit(conn, %{post: post}) do
      with {:ok, conn} <- authorize(conn, post) do
        scope(conn, post)
      end
    end

    def show(conn, %{post: post}) do
      with {:ok, conn} <- authorize(conn, post) do
        scope(conn, post)
      end
    end

    def show_nils_not_found(conn, %{post: post}) do
      with {:ok, conn} <- authorize(conn, post, nils: :not_found) do
        scope(conn, post)
      end
    end

    def show_nils_unauthorized(conn, %{post: post}) do
      with {:ok, conn} <- authorize(conn, post, nils: :unauthorized) do
        scope(conn, post)
      end
    end

    def delete(conn, %{post: post}) do
      with {:ok, conn} <- authorize(conn, post) do
        scope(conn, post)
      end
    end
  end

  test "determining policy modules" do
    assert policy_module(User)        == User.Policy
    assert policy_module(%User{})     == User.Policy
    assert policy_module(nil)         == :error
    assert policy_module("fail")      == :error
  end

  test "policy scopes" do
    guest = %User{role: :guest}
    admin = %User{role: :admin}

    assert scoped(nil, :edit, Post) == :guest_posts_scope
    assert scoped(nil, :index, Post) == :all_posts_scope
    assert scoped(guest, :edit, Post) == :guest_posts_scope
    assert scoped(admin, :edit, Post) == :admin_posts_scope
  end

  test "the example policies" do
    guest = %User{id: 1, role: :guest}
    admin = %User{id: 2, role: :admin}
    post = %Post{user_id: 1}

    assert authorized?(guest, :edit, post)
    assert authorized?(guest, :show, post)
    refute authorized?(guest, :delete, post)

    assert authorized?(admin, :edit, post)
    assert authorized?(admin, :show, post)
    assert authorized?(admin, :delete, post)
  end

  test "controller integration" do
    guest = %User{id: 1, role: :guest}
    admin = %User{id: 2, role: :admin}
    other = %User{id: 3, role: :guest}
    post = %Post{user_id: 1}
    params = %{post: post}

    # Test index action - everyone is authorized! So just test the scope
    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :index}}
    assert PostController.index(conn, params) == :all_posts_scope

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :index}}
    assert PostController.index(conn, params) == :all_posts_scope

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :index}}
    assert PostController.index(conn, params) == :all_posts_scope

    # Test edit action
    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :edit}}
    assert PostController.edit(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :edit}}
    assert PostController.edit(conn, params) == :guest_posts_scope

    conn = %Plug.Conn{assigns: %{current_user: other}, private: %{phoenix_action: :edit}}
    assert PostController.edit(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :edit}}
    assert PostController.edit(conn, params) == :admin_posts_scope

    # Test show action
    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, params) == :guest_posts_scope

    conn = %Plug.Conn{assigns: %{current_user: other}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, params) == :guest_posts_scope

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, params) == :admin_posts_scope

    # Test showing a nil post (not found)
    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show_nils_unauthorized(conn, %{post: nil}) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show_nils_not_found(conn, %{post: nil}) == {:error, :not_found}

    conn = %Plug.Conn{assigns: %{current_user: other}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :unauthorized}

    Application.put_env(:bodyguard, :nils, :not_found)

    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :not_found}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :not_found}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show_nils_unauthorized(conn, %{post: nil}) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :show}}
    assert PostController.show_nils_not_found(conn, %{post: nil}) == {:error, :not_found}

    conn = %Plug.Conn{assigns: %{current_user: other}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :not_found}

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :show}}
    assert PostController.show(conn, %{post: nil}) == {:error, :not_found}

    # Test delete action
    conn = %Plug.Conn{assigns: %{current_user: nil}, private: %{phoenix_action: :delete}}
    assert PostController.delete(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: guest}, private: %{phoenix_action: :delete}}
    assert PostController.delete(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: other}, private: %{phoenix_action: :delete}}
    assert PostController.delete(conn, params) == {:error, :unauthorized}

    conn = %Plug.Conn{assigns: %{current_user: admin}, private: %{phoenix_action: :delete}}
    assert PostController.delete(conn, params) == :admin_posts_scope
  end
end
