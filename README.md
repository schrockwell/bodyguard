# Bodyguard

Bodyguard protects the context boundaries of your application. 💪

Version 2.0 was designed from the ground-up to integrate nicely with Phoenix contexts. Authorization is contained completely within contexts so that the business logic it represents does not leak out. This keeps your contextual actions safe, and ensures consumers do not contain repetitive, error-prone authorization checks. 

To promote reuse and DRY up repetitive configuration, authorization can be constructed and executed in a composable way with `Bodyguard.Action`.

Additionally, the `Bodyguard.Schema` behaviour provides a convention for limiting user-accessible data from within the context.

This is an all-new API, so refer to [the `1.x` branch](https://github.com/schrockwell/bodyguard/tree/1.x) (still maintained!) if you are using versions prior to 2.0.

* [Docs](https://hexdocs.pm/bodyguard/) ← for complete documentation
* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)

## Quick Example

Define authorization rules directly in the context module, in this case `MyApp.Blog`:

```elixir
# lib/my_app/blog.ex
defmodule MyApp.Blog do
  use Bodyguard

  # Bodyguard callback
  def authorize(:update_post, user, post) do
    # Return :ok or true to permit
    # Return :error, {:error, reason}, or false to deny
  end

  # This context function will return:
  #   - {:ok, post} if successful
  #   - {:error, changeset} if operation fails
  #   - {:error, :unauthorized} if authorization fails
  def update_post(user, post_params) do
    post = MyApp.Repo.get!(MyApp.Blog.Post, post_params["id"])
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

## Policies

Add `use Bodyguard` to a context, then define `authorize(action, user, params)` callbacks, which must return:

* `:ok` or `true` to permit the action
* `:error`, `{:error, reason}`, or `false` to deny the action

**Don't use these callbacks directly** – instead, use the wrapper functions injected into the context: `permit/3`, `permit?/3`, and `permit!/3`.

The `action` argument, an atom, might map one-to-one with the actual context function name, or it can be more broad (e.g. `:manage_post` or `:read_post`) to indicate a rule encompassing a wider range of actions.

The passed-in `params` can be any type. If it's a keyword list, then it's coerced into a map to make `authorize/3` pattern-matching more convenient.

```elixir
# lib/my_app/blog.ex
defmodule MyApp.Blog do
  use Bodyguard

  # Admin users can do anything
  def authorize(_, %Blog.User{role: :admin}, _), do: true

  # Regular users can create posts
  def authorize(:create_post, _, _), do: true

  # Regular users can modify their own posts (note the user_id pattern match)
  def authorize(action, %{id: user_id}, %MyApp.Blog.Post{user_id: user_id}),
    do: action in [:update_post, :delete_post]

  # Catch-all: deny everything else
  def authorize(_, _, _), do: false
end
```

If you prefer a more structured approach, define a dedicated policy module outside of the context, and configure the context to `use` it with the `:policy` option:

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

For more info, see `Bodyguard.Policy` in the docs.

## Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures.

The fallback controller should handle any `{:error, reason}` results returned by `authorize/3` callbacks.

Normally, authorization failure results in `{:error, :unauthorized}`. If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and handle it separately in the fallback controller.

```elixir
# lib/my_app/web/controllers/post_controller.ex
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller

  action_fallback MyApp.Web.FallbackController

  def index(conn, _) do
    user = conn.assigns.current_user
    with {:ok, posts} <- MyApp.Blog.list_posts(user) do
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

See the section "Overriding `action/2` for custom arguments" in [the Phoenix.Controller docs](https://hexdocs.pm/phoenix/Phoenix.Controller.html) for a clean way to pass in the `user` to each action.

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

Testing is pretty straightforward – use the `Bodyguard` top-level API.

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

  def scope(query, user, _) do
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

  4. Add `use Bodyguard` to contexts that require authorization, and implement `authorize/3` callbacks.

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
