defmodule Bodyguard.Policy do
  @moduledoc """
  Where authorization rules live.

  Typically the callbacks are designed to be used by `Bodyguard.permit/4` and
  are not called directly.

  The only requirement is to implement the `c:authorize/3` callback:

      defmodule MyApp.MyContext do
        @behaviour Bodyguard.Policy

        def authorize(action, user, params) do
          # Return :ok or {:error, reason}
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

  @type auth_result :: :ok | {:error, reason :: any}

  @doc """
  Callback to authorize a user's action.

  The `action` is whatever user-specified contextual action is being authorized.
  It bears no intrinsic relationship to a controller action, and instead should
  share a name with a particular function on the context.

  To permit an action, return `:ok`. To deny, return `{:error, reason}`.
  """
  @callback authorize(action :: atom, user :: any, params :: %{atom => any}) :: auth_result

  # defp auth_and_run(func, user, args) do
  #   with :ok <- apply(:authorize, [func, user, args]) do
  #     apply(func, [args])
  #   end
  # end

  def get_args(args), do: do_get_args(Enum.reverse(args), [])
  defp do_get_args([], acc), do: acc
  defp do_get_args([{_, _, context} = var | rest], acc) when not is_list(context) do
    do_get_args(rest, [var | acc])
  end
  defp do_get_args([ {_, _, context} | rest], acc) when is_list(context) do
    acc = do_get_args(context, acc)
    do_get_args(rest, acc)
  end
  defp do_get_args([ {_, {_, _, context} = var} | rest], acc) when not is_list(context) do
    acc = [var | acc]
    do_get_args(rest, acc)
  end
  defp do_get_args([atom_val], acc) when is_atom(atom_val), do: acc
  defp do_get_args(hmm, acc) do
    IO.inspect "PROBABLE Problem ----"
    IO.inspect hmm
    acc
  end

  defmacro defauth({func_name,line,func_args}, [do: body]) do
    IO.inspect "============================"
    IO.inspect "Macro Scope"
    IO.inspect func_args
    noauth_func_name = ("__" <> Atom.to_string(func_name) <> "__") |> String.to_atom
    noauth_func = {noauth_func_name, line, func_args}
    auth_args = [{:user, line, nil} | func_args]
    auth_func = {func_name, line, auth_args}

    names = func_args |> get_args |> Enum.map(&elem(&1, 0))

    authed = quote do
      values = unquote(
        func_args
        |> get_args
        |> Enum.map(fn arg ->  quote do
            var!(unquote(arg))
          end
        end)
      )
      map = Enum.zip(unquote(names), values) |> Enum.into(%{})
      args = unquote(names)
        |> Enum.reverse
        |> Enum.reduce([], &([Keyword.get(binding(), &1) | &2]))
      auth_apply(__MODULE__, unquote(func_name), unquote(noauth_func_name), var!(user), map, args)
      # with :ok <- authorize(unquote(func_name), var!(user), map) do
      #   args = unquote(names)
      #     |> Enum.reverse
      #     |> Enum.reduce([], &([Keyword.get(binding(), &1) | &2]))
      #   apply(__MODULE__, unquote(noauth_func_name), args)
      # end
    end

    quote do
      def(unquote(auth_func), unquote([do: authed]))
      def(unquote(noauth_func), unquote([do: body]))
    end
  end

  ####
  # Goal State
  ####
  # def create_user(user, params) do
  #   auth_apply(:create_user, :__create_user__, user, params)
  # end

  # def __create_user__(params) do
  #   # Do stuff
  # end

  def auth_apply(mod, action, real_action, user, param_map, param_list) do
    with :ok <- apply(mod, :authorize, [action, user, param_map]) do
      apply(mod, real_action, param_list)
    end
  end

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Bodyguard.Policy
      import Bodyguard.Policy

      if policy = Keyword.get(opts, :policy) do
        def authorize(action, user, params \\ %{}) do
          unquote(policy).authorize(action, user, params)
        end
      end
    end
  end
end
