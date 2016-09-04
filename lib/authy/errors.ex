defmodule Authy.NotAuthorizedError do
  defexception [:message, :status]
end

defimpl Plug.Exception, for: Authy.NotAuthorizedError do
  def status(exception), do: exception.status || 403 # Forbidden
end
