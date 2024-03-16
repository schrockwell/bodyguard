# Bodyguard

[![Module Version](https://img.shields.io/hexpm/v/bodyguard.svg)](https://hex.pm/packages/bodyguard)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/bodyguard/)
[![Total Download](https://img.shields.io/hexpm/dt/bodyguard.svg)](https://hex.pm/packages/bodyguard)
[![License](https://img.shields.io/hexpm/l/bodyguard.svg)](https://github.com/schrockwell/bodyguard/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/schrockwell/bodyguard.svg)](https://github.com/schrockwell/bodyguard/commits/master)
[![tests](https://github.com/schrockwell/bodyguard/actions/workflows/tests-v2.yml/badge.svg)](https://github.com/schrockwell/bodyguard/actions)

Bodyguard protects the context boundaries of your application. 💪

Authorization callbacks are implemented directly on context modules, so permissions can be checked from controllers, views, sockets, tests, and even other contexts.

The `Bodyguard.Policy` behaviour has a single required callback, `c:Bodyguard.Policy.authorize/3`. Additionally, the `Bodyguard.Schema` behaviour provides a convention for limiting query results per-user.

- [Docs](https://hexdocs.pm/bodyguard/) ← complete documentation
- [Hex](https://hex.pm/packages/bodyguard)
- [GitHub](https://github.com/schrockwell/bodyguard)

## Quick Example

Define authorization rules directly in the context module:

```elixir
# lib/my_app/blog/blog.ex
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy

  # Admins can update anything
  def authorize(:update_post, %{role: :admin} = _user, _post), do: :ok

  # Users can update their owned posts
  def authorize(:update_post, %{id: user_id} = _user, %{user_id: user_id} = _post), do: :ok

  # Otherwise, denied
  def authorize(:update_post, _user, _post), do: :error
end

# lib/my_app_web/controllers/post_controller.ex
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller

  def update(conn, %{"id" => id, "post" => post_params}) do
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

To implement a policy, add `@behaviour Bodyguard.Policy` to a context, then define an `authorize(action, user, params)` callback, which must return:

- `:ok` or `true` to permit an action
- `:error`, `{:error, reason}`, or `false` to deny an action

Don't use these callbacks directly - instead, go through `Bodyguard.permit/4`. This will convert keyword-list `params` into a map, and will coerce the callback result into a strict `:ok` or `{:error, reason}` result. The default failure result is `{:error, :unauthorized}`.

Helpers `Bodyguard.permit?/4` and `Bodyguard.permit!/5` are also provided.

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
  def authorize(action, %Blog.User{id: user_id}, %Blog.Post{user_id: user_id})
    when action in [:update_post, :delete_post], do: true

  # Catch-all: deny everything else
  def authorize(_, _, _), do: false
end
```

If you want to keep the policy separate from the context, define a dedicated policy module and use `defdelegate`:

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

The `action_fallback` controller macro is the recommended way to deal with authorization failures. The fallback controller will handle the `{:error, reason}` results from the main conrollers.

```elixir
# lib/my_app_web/controllers/fallback_controller.ex
defmodule MyAppWeb.FallbackController do
  use MyAppWeb, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> put_view(html: MyAppWeb.ErrorHTML)
    |> render(:"403")
  end
end

# lib/my_app_controllers/page_controller.ex
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  # This can be defined here, or in the MyAppWeb.controller/0 macro
  action_fallback MyAppWeb.FallbackController

  # ...actions here...
end
```

### When Using the Plug

If the `Bodyguard.Plug.Authorize` plug is being used, its `:fallback` option must be specified, since the plug pipeline will be halted before the controller action can be called.

### Returning "404 Not Found"

Typically, failures will result in `{:error, :unauthorized}`. If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and handle it separately in the fallback controller as a 404.

### Related Reading

Bodyguard doesn't make any assumptions about where authorization checks are performed. You can do it before calling into the context, or within the context itself. There is a good discussion of the tradeoffs [in this blog post](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts).

See the section "Overriding `action/2` for custom arguments" in [the Phoenix.Controller docs](https://hexdocs.pm/phoenix/Phoenix.Controller.html) for a clean way to pass in the `user` to each action.

## Plugs

- `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline

This plug's config utilizes callback functions called getters, which are 1-arity functions that
accept the `conn` and return the appropriate value.

```elixir
# lib/my_app_web/controllers/post_controller.ex
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller

  # Fetch the post and put into conn assigns
  plug :get_post when action in [:show]

  # Do the check
  plug Bodyguard.Plug.Authorize,
    policy: MyApp.Blog.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {MyApp.Authentication, :current_user},
    params: {__MODULE__, :extract_post},
    fallback: MyAppWeb.FallbackController

  def show(conn, _) do
    # Already assigned and authorized
    render(conn, "show.html")
  end

  defp get_post(conn, _) do
    assign(conn, :post, MyApp.Posts.get_post!(conn.params["id"]))
  end

  # Helper for the Authorize plug
  def extract_post(conn), do: conn.assigns.posts
end
```

See the docs for more information about configuring application-wide defaults for the plug.

## LiveViews

Authorization checks can be performed in the `mount/3` and `handle_event/3` callbacks of a LiveView. See [the LiveView documentation](https://hexdocs.pm/phoenix_live_view/security-model.html) for hints and examples.

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

## Configuration

Here is the default library config.

```elixir
config :bodyguard,
  # The second element of the {:error, reason} tuple returned on auth failure
  default_error: :unauthorized
```

## Testing

Testing is pretty straightforward – use the `Bodyguard` top-level API.

```elixir
assert :ok == Bodyguard.permit(MyApp.Blog, :successful_action, user)
assert {:error, :unauthorized} == Bodyguard.permit(MyApp.Blog, :failing_action, user)

assert Bodyguard.permit?(MyApp.Blog, :successful_action, user)
refute Bodyguard.permit?(MyApp.Blog, :failing_action, user)

error = assert_raise Bodyguard.NotAuthorizedError, fun ->
  Bodyguard.permit(MyApp.Blog, :failing_action, user)
end
assert %{status: 403, message: "not authorized"} = error
```

## Installation

1.  Add `:bodyguard` to your list of dependencies:

    ```elixir
    # mix.exs
    def deps do
      [
        {:bodyguard, "~> 2.4"}
      ]
    end
    ```

2.  Add `@behaviour Bodyguard.Policy` to contexts that require authorization, and implement `c:Bodyguard.Policy.authorize/3` callbacks.

3.  Create up a [fallback controller](#controllers) to render an error on `{:error, :unauthorized}`.

### Optional Installation Steps

1.  Add `@behaviour Bodyguard.Schema` on schemas available for user-scoping, and implement `c:Bodyguard.Schema.scope/3` callbacks.

2.  Edit `my_app_web.ex` and add `import Bodyguard` to controllers, views, channels, etc.

## Alternatives

Not what you're looking for?

- [Roll your own](https://dockyard.com/blog/2017/08/01/authorization-for-phoenix-contexts)
- [PolicyWonk](https://github.com/boydm/policy_wonk)
- [Canada](https://github.com/jarednorman/canada)
- [Canary](https://github.com/cpjk/canary)

## Community

Join our communities!

- [Slack](https://elixir-lang.slack.com/messages/CHMTNPSEN/)

## License

MIT License, Copyright (c) 2024 Rockwell Schrock
