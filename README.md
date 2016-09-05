# Authy – Simple Authorization

Authy is a tiny authorization library that imposes a simple module naming convention to express authorization.

It supplies some handy functions to DRY up controller actions in Phoenix and other Plug-based apps.

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

  2. Add `import Authy.Controller` to the `controller` section of `web.ex` to make its functions available.

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

## Phoenix and Other Plug Apps

The `Authy.Controller` module contains helper functions designed to provide authorization in controller actions.

* `authorize/3` returns the tuple `{:ok, conn}` on success, and `{:error, :unauthorized}` on failure.
* `authorize!/3` returns a modified `conn` on success, and will raise `Authy.NotAuthorizedError` on failure. By default, this exception will cause Plug to return HTTP status code 403 Forbidden.

A flag is set on the `conn` to indicate that authorization has succeeded. This flag can be checked automatically at the end of the request using the `verify_authorized` plug, which will raise an exception if authorization was never performed. (TODO: add more details about this, maybe in another section, like setup?)

```elixir
defmodule MyApp.PostController do
  use MyApp.Web, :controller
  alias MyApp.Post

  # Authy.Controller has been imported in web.ex

  def index(conn, _params) do
    posts = scope(conn, Post)    # <-- posts in :index are scoped to the current user
    conn
    |> authorize!(Post)          # <-- authorize :index action for Posts in general
    |> render("index.html", posts: posts)
  end

  def show(conn, %{"id" => id}) do
    post = 
      scope(conn, Post)                  # <-- scope can even be used for lookup
      |> Repo.get(id)   

    conn
    |> authorize!(post)                  # <-- authorize the :show action for this particular post
    |> render("show.html", post: post)
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    post = 
      scope(conn, Post)                  # <-- scope can even be used for lookup
      |> Repo.get(id)

    conn = authorize!(conn, post)        # <-- authorize the :update action for this post

    # ...
  end
end
```

In the event that a resource is nil, (TODO)

### Additional Options

* `:policy` – Override the policy module

  ```elixir
  # Using Authy.Controller
  authorize!(conn, post, policy: Admin.policy)
  scope(conn, Post, policy: Admin.policy)
  ```

* `:action` – Override the action

  ```elixir
  authorize!(conn, post, action: :publish)
  scope(conn, Post, action: :publish)
  ```

* `:user` – Override the current user

  ```elixir
  authorize!(conn, post, user: other_user)
  scope(conn, Post, user: other_user)
  ```

* `:error_status` – Override the HTTP return status when authorization fails

  ```elixir
  authorize!(conn, post, error_status: 404)
  ```

* `:nils` – Override the behavior for nil resources

  ```elixir
  authorize!(conn, post, nils: :unauthorized)
  authorize!(conn, post, nils: :not_found)
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

### Common Patterns

#### Policy Helpers

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

#### Controller Policies

What if you have a Phoenix controller that doesn't correspond to one particular resource? Or, maybe you just want to customize how that controller's actions are locked down.

Try creating a policy for the controller itself. `MyApp.FooController.Policy` is completely acceptable.

#### Authorize Entire Controllers and Router Pipelines

TODO

## Not What You're Looking For?

Check out these other libraries:

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
