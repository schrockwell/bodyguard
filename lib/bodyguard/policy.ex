defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.

  Typically the callbacks are designed to be used by `Bodyguard.permit/4` and
  are not called directly.

  The only requirement is to implement the `c:authorize/3` callback:

      defmodule MyApp.MyContext do
        @behaviour Bodyguard.Policy

        def authorize(action, user, params) do
          # Return :ok or true to permit
          # Return :error, {:error, reason}, or false to deny
        end
      end

  To perform authorization checks, use `Bodyguard.permit/4` and friends:

      with :ok <- Bodyguard.permit(MyApp.MyContext, :action_name, user, param: :value) do
        # ...
      end

      if Bodyguard.permit?(MyApp.MyContext, :action_name, user, param: :value) do
        # ...
      end

      Bodyguard.permit!(MyApp.MyContext, :action_name, user, param: :value)

  If you want to define the callbacks in another module, you can `use` this
  module and it will create a `c:authorize/3` callback wrapper for you:

      defmodule MyApp.MyContext do
        use Bodyguard.Policy, policy: Some.Other.Policy
      end

  """

  @type auth_result :: :ok | :error | {:error, reason :: any} | true | false

  @doc """
  Callback to authorize a user's action.

  To permit an action, return `:ok` or `true`. To deny, return `:error`,
  `{:error, reason}`, or `false`.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic relationship to a controller action, and instead should
  share a name with a particular function on the context.
  """
  @callback authorize(action :: atom, user :: any, params :: %{atom => any} | any) :: auth_result

  defp get_names(func_args) do
    {_, arg_names} = Macro.postwalk(func_args, [], &do_get_names/2)
    arg_names
  end
  defp do_get_names({name, _, nil} = node, acc), do: {node, [name | acc]}
  defp do_get_names(node, acc), do: {node, acc}

  defp create_unauthed_method(func_name, line, func_args) do
    noauth_func_name = ("__" <> Atom.to_string(func_name) <> "__") |> String.to_atom
    noauth_func = {noauth_func_name, line, func_args}
    {noauth_func_name, noauth_func}
  end

  defp create_authed_method(func_name, line, nil) do
    {func_name, line, [{:user, line, nil}]}
  end
  defp create_authed_method(func_name, line, func_args) do
    auth_args = [{:user, line, nil} | func_args]
    {func_name, line, auth_args}
  end

  defmacro defauth({func_name,line,func_args}, [do: body]) do
    {noauth_func_name, noauth_func} = create_unauthed_method(func_name,line,func_args)
    auth_func = create_authed_method(func_name,line,func_args)
    arg_names = get_names(func_args)

    quote do
      def unquote(auth_func) do
        arg_map = binding() |> Enum.into(%{})
        arg_values = unquote(arg_names)
          |> Enum.reduce([], &([Keyword.get(binding(), &1) | &2]))
        handle_auth_and_apply(unquote(func_name), unquote(noauth_func_name), var!(user), arg_map, arg_values)
      end
      def(unquote(noauth_func), unquote([do: body]))
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Policy
      import Bodyguard.Policy

      if policy = Keyword.get(opts, :policy) do
        defdelegate authorize(action, user, params), to: policy
      end

      def handle_auth_and_apply(action, action_impl, user, param_map, param_list) do
        with :ok <- apply(__MODULE__, :authorize, [action, user, param_map]) do
          apply(__MODULE__, action_impl, param_list)
        end
      end
      defoverridable handle_auth_and_apply: 5
    end
  end
end
