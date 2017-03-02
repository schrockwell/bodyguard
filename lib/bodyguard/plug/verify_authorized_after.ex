defmodule Bodyguard.Plug.VerifyAuthorizedAfter do
  @behaviour Plug

  @doc false
  def init(opts \\ []) do
    {fallback, opts} = Keyword.pop(opts, :fallback, nil)
    {fallback, opts}
  end

  @doc false
  def call(conn, {nil, opts}) do
    error_message = Keyword.get(opts, :error_message, "no authorization run")
    error_status = Keyword.get(opts, :error_status, 500)

    Plug.Conn.register_before_send conn, fn (after_conn) ->
      if Bodyguard.Conn.authorized?(after_conn) do
        after_conn
      else
        raise Bodyguard.NotAuthorizedError, message: error_message, 
          status: error_status, reason: :no_authorization_run
      end
    end
  end
  def call(conn, {fallback, _opts}) do
    Plug.Conn.register_before_send conn, fn (after_conn) ->
      if Bodyguard.Conn.authorized?(after_conn) do
        after_conn
      else
        fallback.call(after_conn, {:error, :no_authorization_run})
      end
    end
  end
end