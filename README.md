# Bodyguard

Bodyguard protects the boundaries of your application via a simple system of callbacks. 

Policies are just modules and functions, so they can be leveraged in controllers, sockets, views, and contexts.

It also provides the means to build, customize, and finally execute an authorized action in a composable way.

Please refer to [the complete documentation](https://hexdocs.pm/bodyguard/) for details beyond this README.

Version 2.x is not backwards-compatible, so refer to [the *1.x* branch](https://github.com/schrockwell/bodyguard/tree/1.x) as necessary.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Quick Example

```elixir
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy

  def authorize(user, :update_post, %{post: post}) do
    # Return :ok to permit
    # Return {:error, reason} to deny
  end
end

# In a controller, authorize an action
with :ok <- MyApp.Blog.authorize(user, :update_post, %{post: post}) do
  # ...
end
```

## Authorization

Authorization logic is encapsulated in **policy modules** – typically one per context to be authorized.

Define a series of `authorize/3` callbacks in the context, which must return:

* `:ok` to permit the action, or
* `{:error, reason}` to deny the action (most commonly `{:error, :unauthorized}`)

```elixir
defmodule MyApp.Blog do
  @behaviour Bodyguard.Policy

  # Admin users can do anything
  def authorize(%Blog.User{role: :admin}, _, _), do: :ok

  # Regular users can create posts
  def authorize(_, :create_post, _), do: :ok

  # Regular users can modify their own posts
  def authorize(user, action, %{post: post}) when action in [:update_post, :delete_post] 
    and user.id == post.user_id, do: :ok

  # Catch-all: deny everything else
  def authorize(_, _, _), do: {:error, :unauthorized}
end
```

For more details, see `Bodyguard.Policy` in the docs.

## Controller Actions

Phoenix 1.3 introduces the `action_fallback` controller macro. This is the recommended way to deal with authorization failures.

The fallback controller should handle any `{:error, reason}` results returned by `authorize/3` callbacks.

```elixir
defmodule MyApp.Web.FallbackController do
  use MyApp.Web, :controller

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> render(MyApp.Web.ErrorView, :"403")
  end
end

defmodule MyApp.Web.PostController do
  use MyApp.Web, :controller
  alias MyApp.Blog

  def index(conn, _) do
    user = # get current user
    with :ok <- Blog.authorize(user, :list_posts) do
      posts = Blog.list_posts(user)
      render(conn, posts: posts)
    end
  end
end
```

If you wish to deny access without leaking the existence of a particular resource, consider returning `{:error, :not_found}` and handle it appropriately in the fallback controller.

## Composable Actions

TODO

## Plugs

* `Bodyguard.Plug.BuildAction` – create an Action with some defaults on the connection
* `Bodyguard.Plug.Authorize` – perform authorization on that Action in the middle of a pipeline

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
