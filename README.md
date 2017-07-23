# Bodyguard

Bodyguard protects the context boundaries of your application. 💪

**NEW for v2.2: `use Bodyguard` for auth checks directly in contexts – see below**

Version 2.0 was designed from the ground-up to integrate nicely with Phoenix contexts. Authorization is contained completely within contexts so that the business logic it represents does not leak out. This keeps your contextual actions secure and ensures consumers do not contain repetitive authorization checks. 

To promote reuse and DRY up repetitive configuration, authorization can be constructed and executed in a composable way with `Bodyguard.Action`.

Additionally, the `Bodyguard.Schema` behaviour provides a convention for limiting user-accessible data from within the context.

This is an all-new API, so refer to [the `1.x` branch](https://github.com/schrockwell/bodyguard/tree/1.x) (still maintained!) if you are using versions prior to 2.0.

* [Docs](https://hexdocs.pm/bodyguard/) ← for complete documentation
* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)

## Quick Example

Define authorization rules directly in the context module:

```elixir
# lib/my_app/blog.ex
defmodule MyApp.Blog do
  use Bodyguard

  # Bodyguard callback authorize/3
  def authorize(:update_post, user, post) do
    # Return :ok or true to permit
    # Return :error, {:error, reason}, or false to deny
  end

  # This context function will return:
  #   - {:ok, post} if successful
  #   - {:error, changeset} if operation fails
  #   - {:error, :unauthorized} if authorization fails
  def update_post(user, post_id, post_params) do
    post = MyApp.Repo.get!(MyApp.Blog.Post, post_id)
    with :ok <- permit(:update_post, user, post) do  # <-- permit/3 helper function
      do_update_post(post, post_params)
    end
  end

  # Do the heavy lifting here
  defp do_update_post(post, post_params) do
    # ...
  end
end
```

## Contexts

Add `use Bodyguard` to a context, then define `authorize(action, user, params)` callbacks, which must return:

* `:ok` or `true` to permit the action
* `:error`, `{:error, reason}`, or `false` to deny the action

**Don't use these callbacks directly** – instead, use the three wrapper functions injected into the context: 

* `permit/3` to get an `:ok` or `{:error, reason}`
* `permit?/3` to get a boolean
* `permit!/3` to get an `:ok` or raise `Bodyguard.NotAuthorizedError`

Some notes on the arguments:

* `action` can be any atom - doesn't have to match the context function name
* `user` can be any type - you can pass in a struct or even just a user ID
* `params` can be any type - if it's a keyword list, it will be coerced into a map for `authorize/3`

### Separate Policy Module

If you prefer a more structured approach, define a dedicated policy module outside of the context, and configure the context to use it with the `:policy` option:

```elixir
# lib/my_app/blog.ex
defmodule MyApp.Blog do
  use Bodyguard, policy: MyApp.Blog.Policy
end

# lib/my_app/blog/policy.ex
defmodule MyApp.Blog.Policy do
  @behaviour Bodyguard.Policy

  def authorize(action, user, params), do: # ...
end
```

## Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures. The fallback controller should handle `{:error, :unauthorized}` and other errors returned by `authorize/3` callbacks.

If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and render a 404 in the fallback controller.

See the section "Overriding `action/2` for custom arguments" in [the Phoenix.Controller docs](https://hexdocs.pm/phoenix/Phoenix.Controller.html) for a clean way to pass the `current_user` directly to each controller action.

```elixir
# lib/my_app/web/controllers/post_controller.ex
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller

  action_fallback MyApp.Web.FallbackController

  def index(conn, _) do
    with {:ok, posts} <- MyApp.Blog.list_posts(conn.assigns.current_user) do
      render(conn, posts: posts)
    end
  end
end

# lib/my_app/web/controllers/fallback_controller.ex
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> render(MyApp.Web.ErrorView, :"403")
  end
end
```

## Composable Actions

The concept of an authorized action is encapsulated by the `Bodyguard.Action` struct. It can be initialized with defaults, modified during the request cycle, and finally executed in a controller or socket action.

This example is exactly equivalent to the above:

```elixir
# lib/my_app/web/controllers/post_controller.ex
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  import Bodyguard.Action       # Import act/1, permit/3, run/2, etc.

  action_fallback MyApp.Web.FallbackController
  
  def index(conn, _) do
    act(MyApp.Blog)                        # Initialize a %Bodyguard.Action{}
    |> put_user(conn.assigns.current_user) # Assign the user
    |> permit(:list_posts)                 # Check with MyApp.Blog.authorize/3 callback
    |> run(fn action ->                    # Job only executed if authorization passes
      posts = MyApp.Blog.list_posts(action.user)
      render(conn, posts: posts)
    end)                                   # Return the job's result: a rendered conn
  end
end
```

The function passed to `run/2` is called the *job*, and it only executes if authorization succeeds. If not, then the job is skipped, and the result of the authorization failure is returned instead, to be handled by the fallback controller.

This particular example is verbose for demonstration, but the `Bodyguard.Plug.BuildAction` plug can be used to construct an Action with common parameters ahead of time.

There are many more options – see `Bodyguard.Action` in the docs for details.

## Testing

Testing is pretty straightforward – use the context's `permit/3` and friends:

```elixir
assert :ok == MyApp.Blog.permit(:successful_action, user)
assert {:error, :unauthorized} == MyApp.Blog.permit(:failing_action, user)

assert MyApp.Blog.permit?(:successful_action, user)
refute MyApp.Blog.permit?(:failing_action, user)

error = assert_raise Bodyguard.NotAuthorizedError, fun ->
  MyApp.Blog.permit!(:failing_action, user)
end
assert %{status: 403, message: "not authorized"} = error
```

## Plugs

* `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline
* `Bodyguard.Plug.BuildAction` – create an Action with some defaults on the connection

## Schema Scopes

Bodyguard also provides the `Bodyguard.Schema` behaviour to filter out items a user shouldn't access. Implement it directly on schema modules.

```elixir
defmodule MyApp.Blog.Post do
  import Ecto.Query, only: [from: 2]
  @behaviour Bodyguard.Schema

  def scope(query, user, _params) do
    from ms in query, where: ms.user_id == ^user.id
  end
end
```

To leverage scopes, the `scope/3` helper function (not the callback!) can infer the type of a query and automatically defer to the appropriate callback.

```elixir
defmodule MyApp.Blog do
  use Bodyguard

  def list_user_posts(user) do
    Blog.Post
    |> scope(user)          # <-- defers to MyApp.Blog.Post.scope/3
    |> where(draft: false)
    |> Repo.all
  end
end
```

## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [{:bodyguard, "~> 2.1"}]
end
```

  2. Create an error view for handling `403 Forbidden`.

```elixir
defmodule MyApp.ErrorView do
  use MyApp.Web, :view

  def render("403.html", _assigns) do
    "Forbidden"
  end
end
```

  3. Wire up a [fallback controller](#controllers) to render this 403 view on authorization failures.

  4. Add `use Bodyguard` to contexts that require authorization, implement `authorize/3` callbacks, and wrap authorized code in `permit/3` checks.

  5. (Optional) Add `@behaviour Bodyguard.Schema` on schemas available for user-scoping, and implement the `scope/3` callback.

## Alternatives

Not what you're looking for?

* [PolicyWonk](https://github.com/boydm/policy_wonk)
* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2017 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
