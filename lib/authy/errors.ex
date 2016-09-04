defmodule Authy.NotAuthorizedError do
  defexception [:message]
end

defimpl Plug.Exception, for: Authy.NotAuthorizedError do
  def status(_exception), do: 403 # Forbidden
end
