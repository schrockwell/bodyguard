# Authy – Simple Authorization

Authy is a tiny Elixir authorization library that imposes a simple module naming convention to express authorization.

It also supplies some handy macros to DRY up controller actions in Phoenix and other Plug-based apps.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Authy is coming from.

* [Hex](https://hex.pm/packages/authy)
* [GitHub](https://github.com/schrockwell/authy)
* [Docs](https://hexdocs.pm/authy/)

## Installation

  1. Add `authy` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:authy, "~> 0.1.0"}]
    end
    ```

  2. If you are using Phoenix or another Plug-based app, add this configuration to `config.exs`:

    ```elixir
    config :authy,
      unauthorized_handler: {MyApp.AuthyCallbacks, :handle_unauthorized},
      not_found_handler: {MyApp.AuthyCallbacks, :handle_not_found}
    ```

    You'll have to define that handler module. See the Phoenix section below for more info.

    Also add `import Authy.Controller` to the `controller` section of `web.ex` to make macros available.

## Policies

Authorization logic is contained in **policy modules** – one module per resource to be authorized.

To define a policy for a `Post`, create a module `Post.Policy` with the authorization logic defined in `can?(user, action, term)` methods:

```elixir
defmodule Post.Policy do
  # Admin users are god
  def can?(%User{role: :admin}, _action, _post), do: true

  # Regular users can modify their own posts
  def can?(%User{id: user_id, role: :user}, _action, %Post{user_id: post_user_id}) 
    when user_id == post_user_id, do: true

  # Other users (including guest user, nil) can only index and view posts
  def can?(_user, :index, Post), do: true
  def can?(_user, :show, _post), do: true

  # Catch-all: deny everything else
  def can?(_, _, _), do: false
end
```

To query it:

```elixir
owner = %User{id: 1, role: :user}
other = %User{id: 2, role: :user}
admin = %User{id: 3, role: :admin}
post = %Post{user_id: 1}

Authy.authorized?(admin, :edit, post)  # => true
Authy.authorized?(owner, :edit, post)  # => true
Authy.authorized?(other, :edit, post)  # => false
Authy.authorized?(nil, :edit, post)    # => false

Authy.authorized?(admin, :show, post)  # => true
Authy.authorized?(owner, :show, post)  # => true
Authy.authorized?(other, :show, post)  # => true
Authy.authorized?(nil, :show, post)    # => true

# Note this use of the Post module, not the struct;
# they both defer to Post.Policy
Authy.authorized?(nil, :index, Post)   # => true
```

## Policy Scopes

Another idea borrowed from Pundit, **policy scopes** are a way to embed logic about what resources a particular user can see or otherwise access.

It's just another simple naming convention. Define `scope(user, action, opts)` functions in your policy module to utilize it.

```elixir
defmodule Post.Policy
  # ...

  # Admin sees all posts
  def scope(%User{role: :admin}, :index, _opts), 
    do: Ecto.Query.from(Post)

  # User sees their posts only
  def scope(%User{role: :user, id: id}, :index, _opts), 
    do: Ecto.Query.where(Post, user_id: ^id)

  # Guest sees published posts only
  def scope(nil, :index, _opts), 
    do: Ecto.Query.where(Post, published: true)
end
```

And to call it:

```elixir
Authy.scoped(user1, :index) # => posts for user id 1
Authy.scoped(user2, :index) # => posts for user id 2
Authy.scoped(admin, :index) # => all posts
Authy.scoped(nil, :index)   # => published posts
```

You can also pass `opts` keywords to `Authy.scoped/3`, which will be passed along untouched to the `scope/3` method in your policy module, in case some extra parameters are required to build the scope.

## Phoenix and Other Plug Apps

The `Authy.Controller` module has two macros designed to provide authorization in controller actions, `authorize/2` and `scope/2`. They have reasonable defaults which can be overridden for particular cases. 

The macros assume the variable `Plug.Conn` struct `conn` exists, and use it to determine the current user, controller action, and so on. 

```elixir
defmodule MyApp.PostController do
  use MyApp.Web, :controller
  alias MyApp.Post

  # Authy.Controller has been imported in web.ex

  def index(conn, _params) do
    authorize Post do        # <-- block is only executed if authorized
      posts = scope(Post)    # <-- posts in :index are scoped to the current user
      conn |> render("index.html", posts: posts)
    end
  end

  def show(conn, %{"id" => id}) do
    post = scope(Post) |> Repo.get(id)   # <-- scope can even be used for lookup
    authorize post do                    # <-- authorize the :show action for this particular post
      conn |> render("show.html", post: post)
    end
  end
end
```

When authorization fails, Authy will call your unauthorized handler, as defined in the `:unauthorized_handler` config. The handler takes a single argument, `conn`, and should return a `Plug.Conn` with the appropriate adjustments.

You can probably just copy and paste this to start:

```elixir
defmodule MyApp.AuthyCallbacks do
  def handle_unauthorized(conn) do
    conn
    |> Plug.Conn.put_status(:unauthorized)
    |> Phoenix.Controller.html(MyApp.ErrorView.render("401.html"))
    |> Plug.Conn.halt
  end

  def handle_not_found(conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> Phoenix.Controller.html(MyApp.ErrorView.render("404.html"))
    |> Plug.Conn.halt
  end
end
```

In the event that a resource is nil, you may choose to trigger either "unauthorized" (default) or "not found" behavior. This can be customized at the library level by setting the `nils` config option to either `:unauthorized` or `:not_found`. It can also be customized at the action level by passing the same option to the `authorize` macro.

### Additional Options

`policy` – Override the policy module

```elixir
Authy.authorized?(user, :show, post, policy: Admin.Policy)
Authy.scoped(user, Post, policy: Admin.Policy)

# Using Authy.Controller
authorize post, policy: Admin.policy, do: #...
scope(Post, policy: Admin.policy)
```

`action` – Override the action

```elixir
authorize post, action: :publish, do: #...
scope(Post, action: :publish)
```

`user` – Override the current user

```elixir
authorize post, user: other_user, do: #...
scope(Post, user: other_user)
```

`nils` – Override the behavior for nil resources

```elixir
authorize post, nils: :unauthorized, do: #...
authorize post, nils: :not_found
```

## Recommendations

Here are a few helpful tips and conventions to follow when laying out Authy in your app.

### File Naming and Location

Limit one policy module per file, and name the files like `[MODEL]_policy.ex`, for example `user_policy.ex` and `post_policy.ex`.

For plain Elixir apps, place policies in `lib/policies`. For Phoenix web apps, put them in `web/policies` instead.

### Member Versus Collection Actions

For collection actions like `:index`, pass in the module name (an atom) as the resource to be authorized, since there is no instance of data to check against, e.g. `MyApp.User`.

For individual resource actions like `:show`, pass in the struct data itself, e.g. `%MyApp.User{}`.

For scopes, it doesn't matter if you pass in the module or the data - either will work.

### Suggestion: Policy Helpers

Consider creating a generic **policy helper** to collect authorization logic that is common to many different parts of your application. Reuse it by importing it into more specific policies.

```elixir
defmodule MyApp.PolicyHelper do
  # common methods here
end

defmodule MyApp.Post.Policy do
  import MyApp.PolicyHelper

  # ...
end
```

### Suggestion: Controller Policies

What if you have a Phoenix controller that doesn't correspond to one particular resource? Or, maybe you just want to customize how that controllers' actions are locked down.

Try creating a policy for the controller itself. `MyApp.FooController.Policy` is completely acceptable.

## Not What You're Looking For?

Check out these other Elixir authorization libraries:

* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## Ideas for Future Work

* Add helper for controllers that just returns a boolean (no block)
* Add helpers for views
* Add helpers for Phoenix sockets and channels
* Similar to policy scopes, add **policy changesets**, which will build a changeset based on a users' privileges
* ...?
* Profit!

## License

MIT License, Copyright (c) 2016 Rockwell Schrock