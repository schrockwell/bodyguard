# Bodyguard – Simple, Flexibile Authorization

Bodyguard (previously named Authy) is an authorization library that imposes a simple module naming convention to express authorization.

It supplies some handy functions to DRY up controller actions in Phoenix and other Plug-based apps.

It's inspired by the Ruby gem [Pundit](https://github.com/elabs/pundit), so if you're a fan of Pundit, you'll see where Bodyguard is coming from.

* [Hex](https://hex.pm/packages/bodyguard)
* [GitHub](https://github.com/schrockwell/bodyguard)
* [Docs](https://hexdocs.pm/bodyguard/)

## Installation

  1. Add `bodyguard` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bodyguard, "~> 0.4.0"}]
    end
    ```

  2. Add imports in `web.ex` to make convenience functions available.

    ```elixir
    # lib/my_app/web.ex

    defmodule MyApp.Web do
      def controller do
        quote do
          import Bodyguard.Controller  # <-- new
        end
      end
      def view do
        quote do
          import Bodyguard.ViewHelpers  # <-- new
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

The result of a `can?/3` callback is flexibile:

* `true` and `:ok` results count as authorized
* `false`, `:error`, and `{:error, reason}` results are unauthorized

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

## Permitted Attributes

The policy module can also specify which schema attributes may be modified by a given user. Define `permitted_attributes(user, term)` and return a list of atoms.

If you are using Ecto, the result can be passed into `Ecto.Changeset.cast/3` to whitelist parameters in a changeset.

```elixir
defmodule Post.Policy
  # ...

  # Admins can change anything
  def permitted_attributes(%User{role: :admin}, _post) do
    [:title, :body, :user_id]
  end

  # Post authors can only change the post body
  def permitted_attributes(%User{id: user_id}, %Post{user_id: post_user_id})
  when user_id == post_user_id do
    [:body]
  end

  # Otherwise, blacklist everything
  def permitted_attributes(_user, _post), do: []
end
```

## Authorizing Controller Actions

The `Bodyguard.Controller` module contains helper functions designed to provide authorization in controller actions. You should probably import it in `web.ex` so it is available to all controllers.

The user to authorize is retrieved from `conn.assigns[:current_user]`.

* `authorize/3` returns the tuple `{:ok, conn}` on success, and `{:error, reason}` on failure.
* `authorize!/3` returns a modified `conn` on success, and will raise `Bodyguard.NotAuthorizedError` on failure. By default, this exception will cause Plug to return HTTP status code 403 Forbidden.
* `scope/3` will call the appropriate `scope` function on your policy module for the current user
* `permitted_attributes/3` will call the appropriate `permitted_attributes` function on your policy module for the current user
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

### Handling `authorize!/3` Errors

For Phoenix apps, presenting error views in `MyApp.ErrorView` is often enough.

For further customization, or for plain Plug apps, `authorize!/3` raises directly to the router, so you can use `Plug.ErrorHandler` to catch errors caused by Bodyguard.

```elixir
defmodule MyApp.Router do
  use MyApp.Web, :router
  use Plug.ErrorHandler # <-- new
  
  defp handle_errors(conn, %{reason: %Bodyguard.NotAuthorizedError{}}) do
    # redirect or do whatever you want
  end
end
```

### Controller-Wide Authorization

For more sensitive controllers (e.g. admin control panels), you may not want to leak the details of a particular resource's existence. In that case, you can pre-authorize before even attempting to fetch the record, additionally authorizing that particular resource once it has been retrieved from the database.

To lock down an entire controller using this technique, use `authorize!` as a `plug`. Keep in mind you will have to implement `can?/3` functions on the policy to match the module name, even for member actions like `:show` and `:edit`:

```elixir
defmodule MyApp.ManageUserController do
  plug :authorize!, User  # <-- pre-authorize all actions
  # ...
end
```

### Nested Resources

To authenticate a nested resource, it is common to authorize the parent resource before performing the child resource's action. This can also be accomplished via a controller plug.

If the authorization check consists of a simple foreign key comparison (e.g. `current_user` can only modify a resource if its `user_id` equals `current_user.id`), then the resource struct can be constructed in memory without requiring a round-trip to the database.

```elixir
# router.ex
resources "/companies", CompanyController do
  resources "/users", UserController
end

# user_controller.ex
defmodule MyApp.UserController do
  plug :authorize_company!
  
  defp authorize_company!(%{params: %{"company_id" => company_id}} = conn) do
    # Create this Company in-memory since we only care about its ID
    company = %Company{id: company_id}

    # Authorize the :update action of the parent company as a generic
    # policy for this company's user actions
    authorize!(conn, company, action: :update)
  end
end
```

### Additional Options

* `:policy` – Override the policy module

  ```elixir
  authorize!(conn, post, policy: FeaturedPost.Policy)
  scope(conn, Post, policy: FeaturedPost.Policy)
  permitted_attributes(conn, post, policy: FeaturedPost.Policy)
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
  permitted_attributes(conn, post, user: other_user)
  ```

* `:error_status` – Override the HTTP return status when authorization fails

  ```elixir
  authorize!(conn, post, error_status: 404)
  ```

## View Helpers

Authorization may be performed in views via the `Bodyguard.ViewHelpers.can?/4` function, which you should import into your view modules.

```eex
<%= if can?(@conn, :delete, post) do %>
  <%= link "Delete", to: post_path(@conn, :delete, post), method: :delete %>
<% end %>
```

The first argument can be either a `Plug.Conn` or a user model. The `:policy` option may be provided to override the default policy.

## Authorization Outside of Controllers

Policies are just plain old modules, so you can call them directly:

```elixir
Post.Policy.can?(user, :edit, post)  # <-- returns boolean
Post.Policy.scope(user, :index)      # <-- returns query for posts
```

Or you can use the core `Bodyguard` module to determine the policy module automatically.

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

## Not What You're Looking For?

Check out these other libraries:

* [Canada](https://github.com/jarednorman/canada)
* [Canary](https://github.com/cpjk/canary)

## License

MIT License, Copyright (c) 2016 Rockwell Schrock

## Acknowledgements

Thanks to [Ben Cates](https://github.com/bencates) for helping maintain and mature this library.
