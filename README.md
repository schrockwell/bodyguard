# Bodyguard

Bodyguard protects the context boundaries of your application. 💪

Version 2.0 was built from the ground-up to integrate nicely with Phoenix contexts. Authorization callbacks are implemented directly in contexts, so permissions can be checked from controllers, views, sockets, tests, and even other contexts.

To promote reuse and DRY up repetitive configuration, authorization can be constructed and executed in a composable way with `Bodyguard.Action`.

Additionally, the `Bodyguard.Schema` behaviour provides a convention for limiting user-accessible data from within the context.

This is an all-new API, so refer to [the `1.x` branch](https://github.com/schrockwell/bodyguard/tree/1.x) (still maintained!) if you are using versions prior to 2.0.

* [Docs](https://hexdocs.pm/bodyguard/) ← for complete documentation
* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)

## Quick Example

Define authorization rules directly in the context module, in this case `MyApp.Blog`:

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Context # <-- Adds @behaviour and helper functions

  # Implement this callback:
  def authorize(:update_post, user, %{post: post}) do
    # Return :ok to permit
    # Return {:error, reason} to deny
  end
end

# Authorize a controller action:
with :ok <- MyApp.Blog.authorize(:update_post, user, %{post: post}) do
  # ...
end
```

## Policies

To implement a policy behaviour, add `use Bodyguard.Context` to a context, then define `authorize(action, user, params)` callbacks, which must return:

* `:ok` to permit the action, or
* `{:error, reason}` to deny the action (most commonly `{:error, :unauthorized}`)

The `use` macro injects `authorize!/3` (raises on failure) and `authorize?/3` (returns a boolean) wrapper functions for convenience.

The `action` argument, an atom, typically maps one-to-one with the actual context function name, although it can be more broad (e.g. `:manage_post` or `:read_post`) to indicate a rule encompassing a wider range of actions.

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Context

  # Admin users can do anything
  def authorize(_, %Blog.User{role: :admin}, _), do: :ok

  # Regular users can create posts
  def authorize(:create_post, _, _), do: :ok

  # Regular users can modify their own posts
  def authorize(action, user, %{post: post}) 
    when action in [:update_post, :delete_post] 
    and user.id == post.user_id, do: :ok

  # Catch-all: deny everything else
  def authorize(_, _, _), do: {:error, :unauthorized}
end
```

If you prefer a more structured approach, define a dedicated policy module outside of the context, and configure the context to use it with the `:policy` option:

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Context, policy: MyApp.Blog.Policy
end

defmodule MyApp.Blog.Policy do
  use Bodyguard.Policy
  def authorize(action, user, params), do: # ...
end
```

For details, see `Bodyguard.Policy` in the docs.

## Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures.

The fallback controller should handle any `{:error, reason}` results returned by `authorize/3` callbacks.

Normally, authorization failure results in `{:error, :unauthorized}`. If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and handle it separately in the fallback controller.

```elixir
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  alias MyApp.Blog

  action_fallback MyApp.Web.FallbackController

  def index(conn, _) do
    user = # get current user
    with :ok <- Blog.authorize(:list_posts, user) do
      posts = Blog.list_posts(user)
      render(conn, posts: posts)
    end
  end
end

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
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  alias MyApp.Blog
  import Bodyguard.Action       # Import act/1, authorize/3, run/2, etc.

  action_fallback MyApp.Web.FallbackController
  
  def index(conn, _) do
    user = # get current user

    act(Blog)                   # Initialize a %Bodyguard.Action{}
    |> put_user(user)           # Assign the user
    |> authorize(:list_posts)   # Defer to Blog.authorize/3 callback
    |> run(fn action ->         # Job only executed if authorization passes
      posts = Blog.list_posts(action.user)
      render(conn, posts: posts)
    end)                        # Return the job's result: a rendered conn
  end
end
```

The function passed to `run/2` is called the *job*, and it only executes if authorization succeeds. If not, then the job is skipped, and the result of the authorization failure is returned instead, to be handled by the fallback controller.

This particular example is verbose for demonstration, but the `Bodyguard.Plug.BuildAction` plug can be used to construct an Action with common parameters ahead of time.

There are many more options – see `Bodyguard.Action` in the docs for details.

## Testing

Testing is pretty straightforward – just call into the policies directly.

```elixir
assert :ok == MyApp.Blog.authorize(:successful_action, user)
assert {:error, :unauthorized} == MyApp.Blog.authorize(:failing_action, user)

assert MyApp.Blog.authorize?(:successful_action, user)
refute MyApp.Blog.authorize?(:failing_action, user)

error = assert_raise Bodyguard.NotAuthorizedError, fun ->
  MyApp.Blog.authorize!(:failing_action, user)
end
assert %{status: 403, message: "not authorized"} = error
```

## Plugs

* `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline
* `Bodyguard.Plug.BuildAction` – create an Action with some defaults on the connection

## Schema Scopes

Bodyguard also provides the `Bodyguard.Schema` behaviour to query which items a user can access. Implement it directly on schema modules.

```elixir
defmodule MyApp.Blog.Post do
  import Ecto.Query, only: [from: 2]
  use Bodyguard.Schema

  def scope(query, user, _) do
    from ms in query, where: ms.user_id == ^user.id
  end
end
```

To leverage scopes, the `Bodyguard.Schema.scope/3` helper function (not the callback!) can infer the type of a query and automatically defer to the appropriate callback.

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Context     # <-- imports scope/3 helper
  # ...

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
      [{:bodyguard, "~> 2.0.0"}]
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

  3. Wire up a [fallback controller](#controllers) to render this view on authorization failures.

  4. Add `use Bodyguard.Context` to contexts that require authorization, and implement the `authorize/3` callback.

  5. (Optional) Add `use Bodyguard.Schema` on schemas available for user-scoping, and implement the `scope/3` callback.

## Alternatives

Not what you're looking for?

* [PolicyWonk](https://github.com/boydm/policy_wonk)
* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2017 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
