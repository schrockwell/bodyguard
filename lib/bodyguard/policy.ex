defmodule Bodyguard.Policy do
  @type action :: atom | String.t()
  @type context :: %{required(atom | String.t()) => term}

  @type option :: {:only, keyword} | {:fallback_to, boolean | module}
  @type options :: list(option)

  @callback permit?(actor :: term, action :: action, context :: context) :: boolean
  @callback permit!(actor :: term, action :: action, context :: context) :: term | no_return

  @optional_callbacks [permit!: 3]

  @injected_callbacks [permit!: 3]

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

  @doc false
  @spec __using__(options) :: term
  defmacro __using__(opts \\ []) do
    attributes =
      quote do
        @behaviour Bodyguard.Policy
        @bodyguard_opts unquote(opts)
        @before_compile Bodyguard.Policy
      end

    functions =
      opts
      |> Keyword.get(:only, @injected_callbacks)
      |> Enum.map(&injected_callback/1)

    [attributes | functions]
  end

  @doc false
  defmacro __before_compile__(%Macro.Env{module: env_module}) do
    opts = Module.get_attribute(env_module, :bodyguard_opts, [])

    case Keyword.fetch(opts, :fallback_to) do
      {:ok, value} when is_boolean(value) ->
        quote do
          def permit?(_, _, _), do: unquote(value)
        end

      {:ok, module} when is_atom(module) and module != env_module ->
        quote do
          def permit?(actor, action, context) do
            unquote(module).permit?(actor, action, context)
          end
        end

      :error ->
        nil

      _ ->
        raise ArgumentError, "Policy `:fallback_to` option must be a boolean value or another policy module"
    end
  end

  defp injected_callback({:permit!, 3}) do
    quote do
      def permit!(actor, action, context) do
        Bodyguard.Policy.permit!(__MODULE__, actor, action, context)
      end
    end
  end

  defp injected_callback({fun, arity}) do
    raise ArgumentError, "Unexpected option `only: [#{fun}: #{arity}]` passed to `use Bodyguard`"
  end
end
