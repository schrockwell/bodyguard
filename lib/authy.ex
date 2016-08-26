defmodule Authy do
  @moduledoc """
  Authy can be used to authorize user actions for resources. It has no
  external dependencies, so it will work in any Elixir app as a basic 
  authorization mechanism.

  See the README.md for more information and examples.

  For common integration patterns in Plug-based web applications, check out
  Authy.Controller.
  """

  @doc """
  Given a data structure, determines the policy module to call for authorization
  checks, following the Authy convention.

  Returns an atom of the policy module if passed a struct or atom, by appending
  ".Policy" to the module name

      policy_module(MyApp.User)         # => MyApp.User.Policy
      policy_module(%MyApp.User{})      # => MyApp.User.Policy

  Returns :error otherwise.

      policy_module("Derp") # => :error

  """
  def policy_module(nil), do: :error
  def policy_module(%{__struct__: s}), do: policy_module(s)
  def policy_module(atom) when is_atom(atom), do: String.to_atom("#{atom}.Policy")
  def policy_module(_), do: :error

  @doc """
  Returns a boolean determining if the user's action is authorized via the appropriate
  policy module for that resource. Uses `policy_module/1` to find the module, 
  then calls `can?/3` on it, passing in the user, the action (an atom), 
  and the resource to authorize the action on.

      user = %MyApp.User{}
      post = %MyApp.Post{}
      Authy.authorized?(user, :show, post)
      Authy.authorized?(user, :index, MyApp.Post)
  
  You can explicitly specify the policy module using the `:policy` option:

      Authy.authorized?(user, :show, post, policy: MyApp.DraftPost.Policy)
  
  If the policy module is nil, then it returns false.
  """
  def authorized?(user, action, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    !!apply(module, :can?, [user, action, term])
  end

  @doc """
  Scope resources based on the users' authorization. 

  For example, a regular user can only see posts they have created,
  but an admin can see all posts. You can define a `scope/2` method 
  on the policy module to return the appropriate scope for that user.

  Any options are passed through to `opts` on your `scope/2` method.

  This examples scopes an Ecto query of posts a user can see.

      # post_policy.ex

      defmodule MyApp.Post.Policy
        # A user can only see their own posts, but an admin can see all posts
        def scope(user, _action, opts \\ []) do
          case user.role do
            "user" -> MyApp.Post |> where(user_id: ^user.id)
            "admin" -> MyApp.Post
            _ -> {:error, :unknown_role}
          end
        end
      end

      # post_controller.ex

      posts = Authy.scoped(current_user, MyApp.Post) |> Repo.all
  """
  def scoped(user, action, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :scope, [user, action, opts])
  end
end
