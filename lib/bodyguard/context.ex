defmodule Bodyguard.Context do
  @moduledoc """
  Embrace the Bodyguard ecosystem!

  Add authorization and model scoping helpers, in one convenient LOC. This:
  
      defmodule MyApp.MyContext do
        use Bodyguard.Context
      end

  Is exactly equivalent to:

      defmodule MyApp.MyContext do
        use Bodyguard.Policy      # Add authorization behaviour
        import Bodyguard.Schema   # Import scope/3
      end

  See `Bodyguard.Policy` and `Bodyguard.Schema` for details.
  """
  
  @doc false
  defmacro __using__(_) do
    quote do
      use Bodyguard.Policy
      import Bodyguard.Schema
    end
  end
end