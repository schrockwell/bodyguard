defmodule Bodyguard do
  @moduledoc """
  Bodyguard imposes a simple module naming convention to express authorization policies.

  See the README for more information and examples.

  For integration with Plug-based web applications (e.g. Phoenix), check out
  `Bodyguard.Controller`.
  """

  @doc """
  Given a data structure, determines the policy module to call for authorization
  checks, following the Bodyguard convention.

  Returns an atom of the policy module if passed a struct or atom, by appending
  ".Policy" to the module name

      policy_module(MyApp.User)         # => MyApp.User.Policy
      policy_module(%MyApp.User{})      # => MyApp.User.Policy

  Returns `:error` otherwise.

      policy_module("Derp") # => :error

  """
  def policy_module(nil), do: :error
  def policy_module(%{__struct__: s}), do: policy_module(s)
  def policy_module(term) when is_atom(term), do: String.to_atom("#{term}.Policy")
  def policy_module(_), do: :error

  @doc """
  Returns a value determining if the user's action is authorized via the appropriate
  policy module for that resource.

  The result is returned directly from the `can?/3` callback.

  `policy_module/1` is used to find the module, then calls `can?(user, action, term)` on it.

      user = %MyApp.User{}
      post = %MyApp.Post{}
      Bodyguard.authorized?(user, :show, post)
      Bodyguard.authorized?(user, :index, MyApp.Post)
  
  Available options:
  * `policy` (atom) - override the policy determined from the term
  """
  def authorized?(user, action, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :can?, [user, action, term])
  end

  @doc """
  Scope resources based on the current user.

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
      posts = Bodyguard.scoped(current_user, MyApp.Post) |> Repo.all
  """
  def scoped(user, action, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :scope, [user, action, opts])
  end

  @doc """
  Specify which schema attributes may be updated by the current user.

  The policy module must define a function `permitted_attributes(user, term)`
  which returns a list of atoms corresponding to the fields that may 
  be updated. This resulting list is often passed to `Ecto.Changeset.cast/3` 
  to whitelist the parameters being passed in to the changeset.

  Available options:
  * `policy` (atom) - override the policy determined from the term
  """
  def permitted_attributes(user, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :permitted_attributes, [user, term])
  end
end
