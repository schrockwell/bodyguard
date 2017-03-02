# Bodyguard

### Simple, Flexibile Authorization

Bodyguard protects the boundaries of your business domains, known as *contexts* in Phoenix.

Authorization policies – like everything else in Elixir – are just modules and functions, so Bodyguard can be equally leveraged in controllers, sockets, views, and contexts.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Bodyguard is coming from.

Version 1.x will continue to be maintained, but 2.x is not backwards-compatible, so refer to [the *1.x* branch on GitHub](https://github.com/schrockwell/bodyguard/tree/1.x) for the appropriate documentation.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Hello World

Define a policy to control access to the `Blog` context with `permit/3` callbacks:

```elixir
defmodule MyApp.Blog.Policy do
  use Bodyguard.Policy

  def permit(user, :update_post, %{post: post}) do
    # Return :ok to permit
    # Return {:error, reason} to deny
  end
end
```

Do an authorization check with the injected `authorize/3` function:

```elixir
with :ok <- Blog.Policy.authorize(user, :update_post, post: post) do
  # ...
end
```

## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`.

    ```elixir
    def deps do
      [{:bodyguard, "~> 2.0.0"}]
    end
    ```

  2. Add an error view case for handling 403 Forbidden.

    ```elixir
    defmodule MyApp.ErrorView do
      use MyApp.Web, :view

      def render("403.html", _assigns) do
        "Forbidden"
      end
    end
    ```

  3. Wire up a fallback controller to handle `{:error, :unauthorized}`, as shown below.

## Authorization

Authorization logic is encapsulated in **policy modules** – one per context to be authorized.

Define a series of `permit(user, action, params)` callbacks, which must return:

* `:ok` to permit the action
* `{:error, reason}` to deny the action; most commonly `{:error, :unauthorized}`

To trigger the callbacks, call `authorize(actor, action, params)`, where the `actor` is slightly more flexible – it can be a user, a `Plug.Conn`, or a `Phoenix.Socket`.

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

Another idea borrowed from Pundit, **policy scopes** are a way to embed logic about what resources a particular user can see or otherwise access.

Define `filter(user, resource, scope, params)` callbacks to utilize it. Each callback is expected to return a subset of the passed-in `scope` argument.

```elixir
# In a controller action

  drafts = Blog.list_drafts(conn_or_user)

# In MyApp.Blog

  def list_drafts(actor) do
    actor
    |> Blog.Policy.scope(Post)
    |> Repo.all
  end

# In MyApp.Blog.Policy

  # Admin sees all drafts
  def scope(%User{role: :admin}, Post, scope, _), do: scope

  # User sees their drafts only
  def scope(user, Post, scope, _) do
    from p in scope,
      where: p.user_id == ^user.id,
      where: p.status == "draft"
  end
```

The `scope` argument can be a struct, module name, an Ecto query, or a list of structs. If it's something else, you must pass the `resource` option since the type of the resource cannot be inferred automatically.

## Controller Actions

Phoenix 1.3 introduces the `action_fallback` controller macro (TODO: LINK ME). This is the recommended way to deal with authorization failures in Bodyguard.

The fallback controller should handle the `{:error, :unauthorized}` result, as well as any other `{:error, reason}` combinations returned by callbacks.

```elixir
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(TestApp.Web.ErrorView, :"403")
  end
  
  # If using the VerifyAuthorizedAfter plug
  def call(conn, {:error, :no_authorization_run}) do
    conn
    |> put_status(:internal_server_error)
    |> render(TestApp.Web.ErrorView, :"500")
  end
end
```

If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` and handle it appropriately in the fallback controller.

Forgoing fallback controllers, `authorize!/4` will raise `Bodyguard.NotAuthorizedError` to the router, though this is not recommended.

## Plugs

* `Bodyguard.Plug.Guard` – perform authorization in the middle of a pipeline; the `context` and `action` options must be provided, and an optional `fallback` controller may be specified
* `Bodyguard.Plug.PutOptions` – set common options for a particular controller or pipeline
* `Bodyguard.Plug.VerifyAuthorizedAfter` – perform a "sanity check" after the controller action, but before sending the response, to ensure that some authorization was performed via `Bodyguard.Conn.authorize/4`

## Not What You're Looking For?

Check out these other libraries:

* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2016 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
