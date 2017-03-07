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

  #### Options

  * `policy` - if you don't want `authorize/3` callbacks cluttering up your
    context, implement them in a dedicated policy module (e.g.
    `MyApp.MyContext.Policy`) and specify it here

  See `Bodyguard.Policy` and `Bodyguard.Schema` for details.
  """
  
  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Bodyguard.Policy
      import Bodyguard.Schema

      if policy = Keyword.get(opts, :policy) do
        def authorize(action, user, params \\ %{}) do
          unquote(policy).authorize(action, user, params)
        end
      end
    end
  end
end