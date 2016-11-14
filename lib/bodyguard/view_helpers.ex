defmodule Bodyguard.ViewHelpers do
  def can?(conn, action, resource) do
    Bodyguard.Controller.authorized?(conn, resource, action: action)
  end
end
