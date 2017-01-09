defmodule Bodyguard do
  @moduledoc """
  Bodyguard imposes a simple module naming convention to express authorization
  policies.

  For easy integration with Plug-based web applications (e.g. Phoenix), check
  out `Bodyguard.Controller`.
  """

  require Logger

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

  @spec policy_module(term) :: module | :error

  # Unable to determine for nil
  def policy_module(nil), do: :error

  # For Ecto queries
  def policy_module(%{from: {source, schema}})
    when is_binary(source) and is_atom(schema), do: policy_module(schema)

  # For structs
  def policy_module(%{__struct__: s}), do: policy_module(s)

  # For schemas
  def policy_module(term) when is_atom(term), do: String.to_atom("#{term}.Policy")

  # Unable to determine
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
  @spec authorized?(term, atom, term, keyword) :: boolean | :ok | :error | {:error, atom}
  def authorized?(user, action, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :can?, [user, action, term])
  end

  @doc """
  Scope resources based on the current user.

  See also: `Bodyguard.Controller.scope/3`

  Define a `scope(user, action, scope)` callback on the policy module to return
  the appropriate scope for that user.

  If the `scope` argument is a struct, module name, or an Ecto query, the schema
  can be automatically inferred. Otherwise, you must pass the `policy` option to
  explicitly determine the policy.

  This example scopes an Ecto query of posts a user can see.

      # post_policy.ex
      defmodule MyApp.Post.Policy
        # A user can only see their own posts, but an admin can see all posts
        def scope(%{role: "user", id: user_id}, _action, scope) do 
          scope |> where(user_id: user_id)
        end

        def scope(%{role: "admin"}, _action, scope), do: scope
      end

      # elsewhere
      posts = Bodyguard.scoped(current_user, :index, MyApp.Post) |> Repo.all
  """
  @spec scoped(term, atom, term, keyword) :: term
  def scoped(user, action, scope, opts \\ []) do
    module = opts[:policy] || policy_module(scope)

    # TODO v1.0: Remove deprecation warning
    if Keyword.keyword?(opts) && Keyword.keys(opts) != [] && Keyword.keys(opts) != [:policy] do
      Logger.warn("Passing opts to the #{module}.scope/3 callback is deprecated. The new callback function signature is #{module}.scope(user, action, scope). Use the scope argument instead.")
    end

    apply(module, :scope, [user, action, scope])
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
  @spec permitted_attributes(term, term, keyword) :: [atom]
  def permitted_attributes(user, term, opts \\ []) do
    module = opts[:policy] || policy_module(term)
    apply(module, :permitted_attributes, [user, term])
  end
end
