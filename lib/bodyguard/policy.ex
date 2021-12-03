defmodule Bodyguard.Policy do
  @type action :: atom | String.t()
  @type context :: %{required(atom) => term}

  @callback permit?(actor :: term, action :: action, context :: context) :: boolean
  @callback permit!(actor :: term, action :: action, context :: context) :: term | no_return

  @optional_callbacks permit!: 3

  @doc false
  def permit?(policy, actor, action, context) do
    policy.permit?(actor, action, context)
  end

  @doc false
  def permit!(policy, actor, action, context) do
    if policy.permit?(actor, action, context) do
      actor
    else
      raise Bodyguard.NotAuthorizedError,
        actor: actor,
        action: action,
        context: context,
        policy: policy
    end
  end

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour Bodyguard.Policy
      @bodyguard_opts unquote(opts)
      @before_compile Bodyguard.Policy

      def permit!(actor, action, context) do
        Bodyguard.Policy.permit!(__MODULE__, actor, action, context)
      end
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :bodyguard_opts)
    fallback_to = Keyword.get(opts, :fallback_to, nil)

    case fallback_to do
      nil ->
        nil

      value when is_boolean(value) ->
        quote do
          def permit?(_, _, _), do: unquote(fallback_to)
        end

      module when is_atom(module) ->
        quote do
          def permit?(actor, action, context) do
            unquote(module).permit?(actor, action, context)
          end
        end

      _ ->
        raise ArgumentError, "Policy `:fallback` option must be a boolean value or another policy module name"
    end
  end
end
