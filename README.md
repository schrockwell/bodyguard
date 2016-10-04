# Authy is now Bodyguard

Due to potential naming conflicts, the package previously known as **Authy** is now **Bodyguard** beginning with version 0.2.0.

The `authy` package will be removed from Hex, and `bodyguard` will be the new package name from here on out.

This renaming also comes with a number of API changes that differ from `authy`, namely replacing the `authorize` and `scope` block-style macros with standard functions. Details are below.

# Bodyguard – Simple, Flexibile Authorization

Bodyguard is an authorization library that imposes a simple module naming convention to express authorization.

It supplies some handy functions to DRY up controller actions in Phoenix and other Plug-based apps.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Bodyguard is coming from.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bodyguard, "~> 0.2.0"}]
    end
    ```

  2. Add `import Bodyguard.Controller` to the `controller/0` method of `web.ex` to make its functions available.

    ```elixir
    # lib/my_app/web.ex

    defmodule MyApp.Web do
      # ...
      def controller do
        quote do
          # ...
          import Bodyguard.Controller  # <-- new
        end
      end
    end
    ```

  3. Add an error view case for handling 403 Forbidden, for when authorization fails.

    ```elixir
    defmodule MyApp.ErrorView do
      use MyApp.Web, :view
      # ...
      def render("403.html", _assigns) do  # <-- new
        "Forbidden"
      end
    end
    ```

## Policies

Authorization logic is contained in **policy modules** – one module per resource to be authorized.

To define a policy for a `Post`, create a module `Post.Policy` with the authorization logic defined in `can?(user, action, term)` functions:

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

## Authorizing Controller Actions

The `Bodyguard.Controller` module contains helper functions designed to provide authorization in controller actions. You should probably import it in `web.ex` so it is available to all controllers.

The user to authorize is retrieved from `conn.assigns[:current_user]`. You can [customize model to authorization](### Customize user fetching)

* `authorize/3` returns the tuple `{:ok, conn}` on success, and `{:error, :unauthorized}` on failure.
* `authorize!/3` returns a modified `conn` on success, and will raise `Bodyguard.NotAuthorizedError` on failure. By default, this exception will cause Plug to return HTTP status code 403 Forbidden.
* `scope/3` will call the appropriate `scope` function on your policy module for the current user
* The `verify_authorized` plug will ensure that an authorization check was performed. It runs the check at the end of each action, immediately before returning the response, and will fail if authorization was not performed.
* `mark_authorized/1` will explicitly force authorization to succeed

```elixir
defmodule MyApp.PostController do
  use MyApp.Web, :controller
  alias MyApp.Post

  # Bodyguard.Controller has been imported in web.ex

  plug :verify_authorized                     # <-- is run at the END of each action

  def index(conn, _params) do
    posts = scope(conn, Post) |> Repo.all     # <-- posts in :index are scoped to the current user

    conn
    |> authorize!(Post)                       # <-- authorize :index action for Posts in general
    |> render("index.html", posts: posts)
  end

  def show(conn, %{"id" => id}) do
    post = scope(conn, Post) |> Repo.get!(id) # <-- scope used for lookup

    conn
    |> authorize!(post)                       # <-- authorize the :show action for this post
    |> render("show.html", post: post)
  end

  def new(conn, _params) do
    conn = authorize!(conn, Post)             # <-- authorize the :new action for posts
    changeset = Post.changeset(%Post{})

    conn
    |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"post" => post_params}) do
    conn = authorize!(conn, Post)             # <-- authorize the :create action for posts
    changeset = Post.changeset(%Post{}, post_params)

    # do insert...
  end

  def edit(conn, %{"id" => id}) do
    post = scope(conn, Post) |> Repo.get!(id) # <-- scope used for lookup
    changeset = Post.changeset(post)

    conn
    |> authorize!(post)                       # <-- authorize the :edit action for this post
    |> render("edit.html", post: post, changeset: changeset)
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    post = scope(conn, Post) |> Repo.get!(id) # <-- scope used for lookup
    conn = authorize!(conn, post)             # <-- authorize the :update action for this post

    # do update...
  end

  def delete(conn, %{"id" => id}) do
    post = scope(conn, Post) |> Repo.get!(id) # <-- scope used for lookup
    conn = authorize!(conn, post)             # <-- authorize the :delete action for this post

    # do delete...
  end
end
```

### Handling "Not Found"

Note that if `Repo.get!` fails due to an invalid ID, the action will raise an exception and render a 404 Not Found page, which is the desired behavior in most cases.

`nil` data will not defer to any policy module, and will fail authorization by default. If the `:policy` option is explicitly specified, then that policy module will be used, passing `nil` as the data.

### Controller-Wide Authorization

For more sensitive controllers (e.g. admin control panels), you may not want to leak the details of a particular resource's existence. In that case, you can pre-authorize before even attempting to fetch the record, additionally authorizing that particular resource once it has been retrieved.

To lock down an entire controller using this technique, use `authorize!` as a `plug`. Keep in mind you will have to implement `can?/3` functions on the policy to match the module name, even for member actions like `:show` and `:edit`:

```elixir
defmodule MyApp.ManageUserController do
  plug :authorize!, User  # <-- pre-authorize all actions
  # ...
end
```

### Additional Options

* `:policy` – Override the policy module

  ```elixir
  authorize!(conn, post, policy: FeaturedPost.Policy)
  scope(conn, Post, policy: FeaturedPost.Policy)
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

## Authorization Outside of Controllers

Policies are just plain old modules, so you can call them directly:

```elixir
Post.Policy.can?(user, :edit, post)  # <-- returns boolean
Post.Policy.scope(user, :index)      # <-- returns query for posts
```

Or you can use the `Bodyguard` module to determine the policy module automatically.

```elixir
Bodyguard.authorized?(user, :edit, post)  # <-- defers to Post.Policy.can?/3
Bodyguard.scoped(user, :index, Post)      # <-- defers to Post.Policy.scope/3
```

## Common Patterns

### Policy Helpers

Consider creating a generic **policy helper** to collect authorization logic that is common to many different parts of your application. Reuse it by importing it into more specific policies.

```elixir
defmodule MyApp.PolicyHelper do
  # common functions here
end

defmodule MyApp.Post.Policy do
  import MyApp.PolicyHelper

  # ...
end
```

### Controller Policies

What if you have a Phoenix controller that doesn't correspond to one particular resource? Or, maybe you just want to customize how that controller's actions are locked down.

Try creating a policy for the controller itself. `MyApp.FooController.Policy` is completely acceptable.


### Customize user fetching

You can customize `current_user` by specifying the key as atom or function in application:

```elixir
# config.exs
config :bodyguard, :current_user, :current_token # It will use `conn.assigns[:current_token]` for authorization
config :bodyguard, :current_user, fn(conn) -> Enum.random([true, false]) end # Let make user furious, `true` or `false` will use for authorization here
```

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

## Acknowledgements

Thank you to the following contributors:

* [Ben Cates](https://github.com/bencates)
