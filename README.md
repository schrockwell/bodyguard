# Bodyguard

### Simple, Flexibile Authorization

Bodyguard imposes a few simple conventions to express where authorization rules live and how to call them. It is designed to protect the boundaries of your business domains, known as *contexts* in Phoenix.

Authorization policies – like everything else in Elixir – are just modules and functions, so Bodyguard can be effectively leveraged in controllers, sockets, views, and contexts.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Bodyguard is coming from.

Version 1.x will continue to be maintained, but 2.x is not backwards-compatible, so refer to [the *1.x* branch on GitHub](https://github.com/schrockwell/bodyguard/tree/1.x) for the appropriate documentation.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Hello World

Define a policy to control access to the `Blog` context:

```elixir
defmodule MyApp.Blog.Policy do
  def guard(user, :update_post, %{post: post}) do
    # Return :ok or true to permit
    # Return :error, {:error, reason}, or false to deny
  end
end
```

Do an authorization check:

```elixir
with :ok <- Bodyguard.guard(user, MyApp.Blog, :update_post, post: post) do
  update_post()
end
```

Bodyguard can extract the current user's identity from a `Plug.Conn` or `Phoenix.Socket` if you have `assigns[:current_user]` defined.

```elixir
# In a controller
with :ok <- Bodyguard.guard(conn, MyApp.Blog, :update_post, post: post) do
  update_post()
end
```
## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`.

    ```elixir
    def deps do
      [{:bodyguard, "~> 2.0.0"}]
    end
    ```

  2. Add imports to `lib/my_app/web.ex` where appropriate.

    ```elixir
    defmodule MyApp.Web do
      def controller do
        quote do
          import Bodyguard, only: [guard: 4, limit: 4]
        end
      end
      # ... same for view
      # ... same for channel
    end
    ```

  3. Add an error view case for handling 403 Forbidden.

    ```elixir
    defmodule MyApp.ErrorView do
      use MyApp.Web, :view

      def render("403.html", _assigns) do
        "Forbidden"
      end
    end
    ```

  4. Wire up a fallback controller to handle `{:error, :unauthorized}`, as shown below.

## Guarding Actions

Authorization logic is encapsulated in **policy modules** – one per context to be authorized.

To define a policy for `MyApp.Blog`, define `MyApp.Blog.Policy` with the authorization logic outlined in a series of `guard(user, action, params)` functions:

```elixir
defmodule MyApp.Blog.Policy do
  # Admin users can do anything
  def guard(%User{role: :admin}, _, _), do: :ok

  # Regular users can create posts
  def guard(_, :create_post, _), do: :ok

  # Regular users can modify their own posts
  def guard(user, action, %{post: post}) when action in [:update_post, :delete_post] 
    and user.id == post.user_id, do: :ok

  # Catch-all: deny everything else
  def guard(_, _, _), do: {:error, :unauthorized}
end
```

The result of a `guard/3` callback is flexibile:

* `true` and `:ok` are considered authorized
* `false`, `:error`, and `{:error, reason}` are considered unauthorized

## Limiting Access

Another idea borrowed from Pundit, **policy scopes** are a way to embed logic about what resources a particular user can see or otherwise access.

Define `limit(user, resource, scope, params)` callbacks to utilize it. Each callback is expected to return a subset of the passed-in `scope` argument.

```elixir
# In a controller action

  drafts = Blog.list_drafts(conn_or_user)

# In MyApp.Blog

  def list_drafts(actor) do
    actor
    |> Bodyguard.limit(Blog, :list_drafts, Post) # <- defers to MyApp.Blog.Policy
    |> Repo.all
  end

# In MyApp.Blog.Policy

  # Admin sees all drafts
  def scope(%User{role: :admin}, Post, :list_drafts, scope, _), do: scope

  # User sees their drafts only
  def scope(user, Post, :list_drafts, scope, _) do
    from p in scope,
      where: p.user_id == ^user.id,
      where: p.status == "draft"
  end
```

The `scope` argument can be a struct, module name, an Ecto query, or a list of structs. If it's something else, you must pass the `policy` option since the type of the resource cannot be inferred automatically.

## Authorization Failure in Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro (TODO: LINK ME). This is the recommended way to deal with authorization failure in Bodyguard.

The fallback controller should handle the `{:error, :unauthorized}` result, as well as any custom `{:error, reason}` results returned by callbacks.

```elixir
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(TestApp.Web.ErrorView, :"403")
  end
end
```
If you wish to deny access without leaking the existence of a particular resource, you can return `{:error, :not_found}` from an authorization check and handle it appropriately in the fallback controller.

In lieu of fallback controllers, you can utilize `Bodyguard.guard!/4`, which will raise `Bodyguard.NotAuthorizedError` to the router, though this is not recommended.

## Plugs

Use `Bodyguard.Plug.Guard` to perform authorization in the middle of a pipeline. The `context` and `action` options must be provided, and an optional `fallback` controller may be specified.

Use `Bodyguard.Plug.PutOptions` to set common options for a particular controller or pipeline.

## Not What You're Looking For?

Check out these other libraries:

* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2016 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
