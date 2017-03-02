defmodule Bodyguard.Plug.VerifyAuthorized do
  @behaviour Plug

  def init(opts \\ []) do
    {fallback, opts} = Keyword.pop(opts, :fallback, nil)
    {fallback, opts}
  end

  def call(conn, {nil, opts}) do
    error_message = Keyword.get(opts, :error_message, "no authorization run")
    error_status = Keyword.get(opts, :error_status, 403)

    if Bodyguard.Conn.authorized?(conn) do
      conn
    else
      raise Bodyguard.NotAuthorizedError, message: error_message, status: error_status,
        reason: :no_authorization_run
    end
  end

  def call(conn, {fallback, _opts}) do
    if Bodyguard.Conn.authorized?(conn) do
      conn
    else
      fallback.call(conn, {:error, :no_authorization_run})
    end
  end
end