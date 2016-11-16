defmodule Bodyguard.NotAuthorizedError do
  @moduledoc """
  This exception is raised when authorization fails, or when 
  an authorization check has not been performed by the end of
  the Plug pipeline.
  """
  defexception [:message, :status, :reason]
end

defimpl Plug.Exception, for: Bodyguard.NotAuthorizedError do
  def status(exception), do: exception.status || 403 # Forbidden
end
