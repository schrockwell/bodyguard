defmodule Bodyguard.NotAuthorizedError do
  @moduledoc """
  Raised when authorization fails.
  """
  defexception [:message, :status, :reason]
end

defimpl Plug.Exception, for: Bodyguard.NotAuthorizedError do
  def status(exception), do: exception.status || 403 # Forbidden
end
