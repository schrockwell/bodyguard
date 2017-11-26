# Bodyguard

Bodyguard protects the context boundaries of your application. 💪

Version 2.x was built from the ground-up to integrate nicely with Phoenix contexts. Authorization callbacks are implemented directly on contexts, so permissions can be checked from controllers, views, sockets, tests, and even other contexts.

The `Bodyguard.Policy` behaviour is implemented with a single required callback. Additionally, the `Bodyguard.Schema` behaviour provides a convention for limiting query results per-user.

This is an all-new API, so refer to [the `1.x` branch](https://github.com/schrockwell/bodyguard/tree/1.x) (still maintained!) if you are using versions prior to 2.0.

* [Docs](https://hexdocs.pm/bodyguard/) ← complete documentation
* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)

## Quick Example

Define authorization rules directly in the context module:

```elixir
# lib/my_app/blog/blog.ex
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy

  # Bodyguard callback
  def authorize(:update_post, user, post) do
    # Return :ok or true to permit
    # Return :error, {:error, reason}, or false to deny
  end
end

# lib/my_app_web/controllers/post_controller.ex
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller

  def update(conn, %{"id" => id, "post" => post_params})
    user = conn.assigns.current_user
    post = MyApp.Blog.get_post!(id)

    with :ok <- Bodyguard.permit(MyApp.Blog, :update_post, user, post),
      {:ok, post} <- MyApp.Blog.update_post(post, post_params)
    do
      redirect(conn, to: post_path(conn, :show, post))
    end
  end
end
```

## Policies

To implement a policy, add `@behaviour Bodyguard.Policy` to a context, then define `authorize(action, user, params)` callbacks, which must return:

* `:ok` or `true` to permit an action
* `:error`, `{:error, reason}`, or `false` to deny an action

Don't use these callbacks directly - instead, go through `Bodyguard.permit/4`. This will convert any keyword-list `params` into a map, and will coerce the callback result into a strict `:ok` or `{:error, reason}` result. The default failure `reason` is `:unauthorized` unless specified otherwise in the callback.

Also provided are `Bodyguard.permit?/4` (returns a boolean) and `Bodyguard.permit!/5` (rasies `Bodyguard.NotAuthorizedError` on failure).

```elixir
# lib/my_app/blog/blog.ex
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy
  alias __MODULE__

  # Admin users can do anything
  def authorize(_, %Blog.User{role: :admin}, _), do: true

  # Regular users can create posts
  def authorize(:create_post, _, _), do: true

  # Regular users can modify their own posts
  def authorize(action, %Blog.User{id: user_id}, %Blog.Post{user_id: user_id}})
    when action in [:update_post, :delete_post], do: true

  # Catch-all: deny everything else
  def authorize(_, _, _), do: false
end
```

If you prefer more structure, define a dedicated policy module outside of the context, and use `defdelegate`:

```elixir
# lib/my_app/blog/blog.ex
defmodule MyApp.Blog do
  defdelegate authorize(action, user, params), to: MyApp.Blog.Policy
end

# lib/my_app/blog/policy.ex
defmodule MyApp.Blog.Policy do
  @behaviour Bodyguard.Policy

  def authorize(action, user, params), do: # ...
end
```

## Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures. The fallback controller will handle `{:error, reason}` authorization failures.

Typically, authorization failure results in `{:error, :unauthorized}`. If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and handle it separately in the fallback controller.

See the section "Overriding `action/2` for custom arguments" in [the Phoenix.Controller docs](https://hexdocs.pm/phoenix/Phoenix.Controller.html) for a clean way to pass in the `user` to each action.

```elixir
# lib/my_app_web/controllers/fallback_controller.ex
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> render(MyAppWeb.ErrorView, :"403")
  end
end
```

### Where Should I Perform Checks?

Bodyguard doesn't make any assumptions about where authorization checks are performed. You can do it before calling into the context, or within the context itself. There is a good discussion of the tradeoffs [here](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts).

## Plugs

* `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline

## Schema Scopes

Bodyguard also provides the `Bodyguard.Schema` behaviour to query which items a user can access. Implement it directly on schema modules.

```elixir
# lib/my_app/blog/post.ex
defmodule MyApp.Blog.Post do
  import Ecto.Query, only: [from: 2]
  @behaviour Bodyguard.Schema

  def scope(query, %MyApp.Blog.User{id: user_id}, _) do
    from ms in query, where: ms.user_id == ^user_id
  end
end
```

To leverage scopes, the `Bodyguard.scope/4` helper function (not the callback!) can infer the type of a query and automatically defer to the appropriate callback.

```elixir
# lib/my_app/blog/blog.ex
defmodule MyApp.Blog do
  def list_user_posts(user) do
    MyApp.Blog.Post
    |> Bodyguard.scope(user) # <-- defers to MyApp.Blog.Post.scope/3
    |> where(draft: false)
    |> Repo.all
  end
end
```

## Testing

Testing is pretty straightforward – use the `Bodyguard` top-level API.

```elixir
assert :ok == Bodyguard.permit(MyApp.Blog, :successful_action, user)
assert {:error, :unauthorized} == Bodyguard.permit(MyApp.Blog, :failing_action, user)

assert Bodyguard.permit(MyApp.Blog, :successful_action, user)
refute Bodyguard.permit(MyApp.Blog, :failing_action, user)

error = assert_raise Bodyguard.NotAuthorizedError, fun ->
  Bodyguard.permit(MyApp.Blog, :failing_action, user)
end
assert %{status: 403, message: "not authorized"} = error
```

## Installation

  1. Add `bodyguard` to your list of dependencies:

```elixir
# mix.exs
def deps do
  [{:bodyguard, "~> 2.1"}]
end
```

  2. Create an error view for handling `403 Forbidden`.

```elixir
# lib/my_app_web/views/error_view.ex
defmodule MyAppWeb.ErrorView do
  use MyAppWeb, :view

  def render("403.html", _assigns) do
    "Forbidden"
  end
end
```

  3. Wire up a [fallback controller](#controllers) to render this error view on `{:error, :unauthorized}`.

  4. Add `@behaviour Bodyguard.Policy` to contexts that require authorization, and implement `authorize/3` callbacks.

  5. (Optional) Add `@behaviour Bodyguard.Schema` on schemas available for user-scoping, and implement `scope/3` callbacks.

  6. (Optional) Edit `my_app_web.ex` and add `import Bodyguard` to controllers, views, channels, etc.

## Alternatives

Not what you're looking for?

* [Roll your own](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts)
* [PolicyWonk](https://github.com/boydm/policy_wonk)
* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2017 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
