# Bodyguard

### Simple, Flexibile Authorization

Bodyguard protects the boundaries of your application via a simple system of callbacks.

Policies are just modules and functions, so they can be leveraged in controllers, sockets, views, and contexts.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Bodyguard is coming from.

Version 2.x is not backwards-compatible, so refer to [the *1.x* branch](https://github.com/schrockwell/bodyguard/tree/1.x) as necessary.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Quick Example

```elixir
defmodule MyApp.Blog.Policy do
  use Bodyguard.Policy

  def permit(user, :update_post, %{post: post}) do
    # Return :ok to permit
    # Return {:error, reason} to deny
  end

  def filter(user, :list_drafts, scope, _) do
    # Return a user's drafts via the scope
  end
end

# In a controller, authorize an action
with :ok <- MyApp.Blog.Policy.authorize(conn, :update_post, post: post) do
  # ...
end

# In a context, limit visible posts
drafts =
  user
  |> MyApp.Blog.Policy.scope(:list_drafts, Post)
  |> Repo.all
```

## Authorization

Authorization logic is encapsulated in **policy modules** – typically one per context to be authorized.

You define a series of `c:Bodyguard.Policy.permit/3` callbacks, which must return:

* `:ok` to permit the action
* `{:error, reason}` to deny the action (most commonly `{:error, :unauthorized}`)

To perform authorization via these callbacks, call `c:Bodyguard.Policy.authorize/3`, where the `actor` is slightly more flexible – it can be a user, a `Plug.Conn`, or a `Phoenix.Socket`.

```elixir
defmodule MyApp.Blog.Policy do
  use Bodyguard.Policy

  # Admin users can do anything
  def permit(%User{role: :admin}, _, _), do: :ok

  # Regular users can create posts
  def permit(_, :create_post, _), do: :ok

  # Regular users can modify their own posts
  def permit(user, action, %{post: post}) when action in [:update_post, :delete_post] 
    and user.id == post.user_id, do: :ok

  # Catch-all: deny everything else
  def permit(_, _, _), do: {:error, :unauthorized}
end
```

## Scopes

**Policy scopes** are a way to embed logic about what resources a particular user can see or otherwise access.

Define `c:Bodyguard.Policy.filter/4` callbacks to utilize scopes. Each callback is expected to return a subset of the passed-in `scope` argument.

To perform scoping via these filters, call `c:Bodyguard.Policy.scope/4`.

```elixir
defmodule MyApp.Blog.Policy do
  use Bodyguard.Policy

  # Admin sees all drafts
  def filter(%User{role: :admin}, :list_drafts, scope, _), do: scope

  # Regular user sees their drafts only
  def filter(user, :list_drafts, scope, _) do
    from post in scope, where: post.user_id == ^user.id
  end
end
```

## Controller Actions

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures.

The fallback controller should handle any `{:error, reason}` results returned by callbacks.

```elixir
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(MyApp.Web.ErrorView, :"403")
  end
end
```

If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` and handle it appropriately in the fallback controller.

If you are using the `Bodyguard.Plug.VerifyAuthorizedAfter` plug, then add a handler for `{:error, :no_authorization_run}` to return a 500.

If you wish to forgo fallback controllers, `authorize!/3` will raise `Bodyguard.NotAuthorizedError` to the router, though this is not recommended.

## Plugs

* `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline
* `Bodyguard.Plug.PutOptions` – set common options for a particular controller or pipeline
* `Bodyguard.Plug.VerifyAuthorizedAfter` – perform a "sanity check" after the controller action, but before sending the response, to ensure that some authorization was performed via `Bodyguard.Policy.authorize_conn/3`

## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`.

    ```elixir
    def deps do
      [{:bodyguard, "~> 2.0.0"}]
    end
    ```

  2. Add an error view for handling 403 Forbidden.

    ```elixir
    defmodule MyApp.ErrorView do
      use MyApp.Web, :view

      def render("403.html", _assigns) do
        "Forbidden"
      end
    end
    ```

  3. Wire up a fallback controller to handle authorization failures, [as mentioned above](#controller-actions).


## Alternatives

Not what you're looking for?

* [PolicyWonk](https://github.com/boydm/policy_wonk)
* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2017 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
