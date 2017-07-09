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

  # defp get_args(func_args) do
  #   {_, args} = func_args
  #     |> Enum.reverse
  #     |> Macro.postwalk([], fn
  #       {name, _, nil} = node, acc -> {node, [node | acc]}
  #       node, acc -> {node, acc}
  #     end)
  #   args
  # end

  defp get_names(func_args) do
    {_, arg_names} = func_args
      |> Enum.reverse
      |> Macro.postwalk([], fn
        {name, _, nil} = node, acc -> {node, [name | acc]}
        node, acc -> {node, acc}
      end)
    arg_names
  end

  defmacro defauth({func_name,line,func_args}, [do: body]) do
    IO.inspect "============================"
    IO.inspect "Macro Scope"
    IO.inspect func_args

    # create unauthed method sig header (function)
    noauth_func_name = ("__" <> Atom.to_string(func_name) <> "__") |> String.to_atom
    noauth_func = {noauth_func_name, line, func_args}

    # create authed method sig header (function)
    auth_args = [{:user, line, nil} | func_args]
    auth_func = {func_name, line, auth_args}

    # <block>This block of code confuses me. Couldn't I just use what I did w/ 'args' for
    # the entire block>
    names = get_names(func_args)
    authed = quote do
      # values = unquote(
      #   func_args
      #   |> get_args
      #   |> Enum.map(fn arg -> quote do
      #       var!(unquote(arg))
      #     end
      #   end)
      # )
      # map = Enum.zip(unquote(names), values) |> Enum.into(%{})
      # </block>
      # Functionalize.  I could optimize it if that's possible, but I'm not sure
      # it's not already fast this way. (function)
      arg_map = binding() |> Enum.into(%{})
      arg_values = unquote(names)
        |> Enum.reverse
        |> Enum.reduce([], &([Keyword.get(binding(), &1) | &2]))
      auth_apply(__MODULE__, unquote(func_name), unquote(noauth_func_name), var!(user), arg_map, arg_values)
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

  # Is passing in the 'mod' value from the Caller scope the best way to do this?
  # seems like there ought to be another way.  Also, rename the parameters, and create
  # @spec calls!
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
