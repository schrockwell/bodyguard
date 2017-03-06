# Bodyguard

Bodyguard protects the context boundaries of your application. 

The `Bodyguard.Policy` behaviour is implemented directly in the context itself, to be queried from controllers, sockets, views, tests, and even other contexts.

To promote reuse and DRY up repetitive configuration, `Bodyguard.Action` structs encapsulate authorized actions in a composable way.

Please refer to [the complete documentation](https://hexdocs.pm/bodyguard/) for details beyond this README.

Version 2.0 has an all-new API, so refer to [the `1.x` branch](https://github.com/schrockwell/bodyguard/tree/1.x) (still maintained!) if you are using versions prior to 2.0.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Quick Example

Define authorization rules directly in the context module, in this case `MyApp.Blog`:

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Policy

  def authorize(user, :update_post, %{post: post}) do
    # Return :ok to permit
    # Return {:error, reason} to deny
  end
end

# Authorize a controller action
with :ok <- MyApp.Blog.authorize(user, :update_post, %{post: post}) do
  # ...
end
```

## Policies

To implement a policy behaviour, add `use Bodyguard.Policy`, then define `authorize(user, action, params)` callbacks, which must return:

* `:ok` to permit the action, or
* `{:error, reason}` to deny the action (most commonly `{:error, :unauthorized}`)

The `use` macro injects `authorize!/3` (raises on failure) and `authorize?/3` (returns a boolean) wrapper functions for convenience.

The `action` argument, an atom, typically maps one-to-one with the actual context function name, although it can be more broad (e.g. `:manage_post` or `:read_post`) to indicate a rule encompassing a wider range of actions.

For details, see `Bodyguard.Policy` in the docs.

```elixir
defmodule MyApp.Blog do
  use Bodyguard.Policy

  # Admin users can do anything
  def authorize(%Blog.User{role: :admin}, _, _), do: :ok

  # Regular users can create posts
  def authorize(_, :create_post, _), do: :ok

  # Regular users can modify their own posts
  def authorize(user, action, %{post: post}) 
    when action in [:update_post, :delete_post] 
    and user.id == post.user_id, do: :ok

  # Catch-all: deny everything else
  def authorize(_, _, _), do: {:error, :unauthorized}
end
```

## Controllers

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures.

The fallback controller should handle any `{:error, reason}` results returned by `authorize/3` callbacks.

Normally, authorization failure results in `{:error, :unauthorized}`. If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` instead, and handle it separately in the fallback controller.

```elixir
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:forbidden)
    |> render(MyApp.Web.ErrorView, :"403")
  end
end

defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  alias MyApp.Blog

  action_fallback MyApp.Web.FallbackController

  def index(conn, _) do
    user = # get current user
    with :ok <- Blog.authorize(user, :list_posts) do
      posts = Blog.list_posts(user)
      render(conn, posts: posts)
    end
  end
end
```

See the note "Overriding `action/2` for custom arguments" in [the Phoenix.Controller docs](https://hexdocs.pm/phoenix/Phoenix.Controller.html) for a clean way to pass in the `user` to each action.

## Composable Actions

The concept of an authorized action is encapsulated by the `Bodyguard.Action` struct. It can be initialized with defaults, modified during the request cycle, and finally executed in a controller or socket action.

This example is exactly equivalent to the above:

```elixir
defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  import Bodyguard.Action       # Import act/1, authorize/3, run/2, etc.
  alias MyApp.Blog

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
assert :ok == MyApp.Blog.authorize(user, :successful_action)
assert {:error, :unauthorized} == MyApp.Blog.authorize(user, :failing_action)

assert MyApp.Blog.authorize?(user, :successful_action)
refute MyApp.Blog.authorize?(user, :failing_action)

error = assert_raise Bodyguard.NotAuthorizedError, fun ->
  MyApp.Blog.authorize!(user, :failing_action)
end
assert %{status: 403, message: "not authorized"} = error
```

## Plugs

* `Bodyguard.Plug.BuildAction` – create an Action with some defaults on the connection
* `Bodyguard.Plug.Authorize` – perform authorization in the middle of a pipeline

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

  4. Add `use Bodyguard.Policy` to contexts that require authorization, and implement the `authorize/3` callback.

## Alternatives

Not what you're looking for?

* [PolicyWonk](https://github.com/boydm/policy_wonk)
* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2017 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
