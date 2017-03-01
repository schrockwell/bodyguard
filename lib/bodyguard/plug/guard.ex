defmodule Bodyguard.Plug.Guard do
  @moduledoc """
  Performs authorization checks in a Plug pipeline.

  The `context` and `action` options are *required*, since they cannot 
  be automatically determined in the middle of the pipeline.

  ## Options

  * `context` *required* - the context to authorize against
  * `action` *required* - the action to authorize (will be the same for all requests,
  regardless of the controller action)
  * `fallback` - the fallback controller that will handle authorization failure. If
  this option is not specified, authorization failure will raise 
  `Bodyguard.NotAuthorizedError` directly to the router.

  ## Example

      plug Bodyguard.Plug.Guard, context: MyApp.Blog, action: :access_posts,
        fallback: MyApp.Web.FallbackController

  """

  @doc false
  def init(opts \\ []) do
    {context,  opts} = Keyword.pop(opts, :context,  nil)
    {action,   opts} = Keyword.pop(opts, :action,   nil)
    {fallback, opts} = Keyword.pop(opts, :fallback, nil)

    if is_nil(context) and is_nil(action) do
      raise ArgumentError, "Bodyguard.Plug.Guard options must specify both a :context and an :action"
    end

    {context, action, opts, fallback}
  end

  @doc false
  def call(conn, {context, action, opts, nil}) do
    Bodyguard.guard!(conn, context, action, opts)
    conn
  end
  def call(conn, {context, action, opts, fallback}) do
    case Bodyguard.guard(conn, context, action, opts) do
      :ok -> conn
      result -> fallback.call(conn, result)
    end
  end
end