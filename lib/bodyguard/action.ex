defmodule Bodyguard.Action do
  @moduledoc """
  Execute authorized actions in a composable way.

  An Action can be built up over the course of a request, providing a means to
  specify authorization parameters in the steps leading up to actually
  executing the job.

  When authorization fails, there is an opportunity to handle it using a
  fallback function before returning the final result.

  Authorization is performed by deferring to a `Bodyguard.Policy`.

  #### Fields

  * `:context` – Context for the action
  * `:policy` – Implementation of `Bodyguard.Policy` behaviour; defaults to the `:context`
  * `:user` – The user to authorize
  * `:name` – The name of the authorized action
  * `:auth_run?` – If an authorization check has been performed
  * `:auth_result` – Result of the authorization check
  * `:authorized?` – If authorization has succeeded (default `false`)
  * `:job` – Function to execute if authorization passes; signature `job(action)`
  * `:fallback` – Function to execute if authorization fails; signature `fallback(action)`
  * `:assigns` – Generic parameters along for the ride

  #### Controller Example

      defmodule MyApp.Web.PostController do
        use MyApp.Web, :controller
        import Bodyguard.Action
        alias MyApp.Blog

        action_fallback MyApp.FallbackController
        plug Bodyguard.Plug.BuildAction, context: Blog, user: &get_current_user/1

        def index(conn, _) do
          run conn.assigns.action, fn(action) ->
            posts = Blog.list_posts(action.user)
            render(conn, "index.html", posts: posts)
          end
        end

        defp get_current_user(conn) do
          # ...
        end
      end

  #### Verbose Example

      import Bodyguard.Action
      alias MyApp.Blog

      act(Blog)
      |> put_user(get_current_user())
      |> put_policy(Blog.SomeSpecialPolicy)
      |> assign(:drafts, true)
      |> authorize(:list_posts)
      |> put_job(fn action ->
        Blog.list_posts(action.user, drafts_only: action.assigns.drafts)
      end)
      |> put_fallback(fn _action -> {:error, :not_found} end)
      |> run()

  """

  defstruct context: nil,
            policy: nil,
            user: nil,
            name: nil,
            auth_run?: false,
            auth_result: nil,
            authorized?: false,
            job: nil,
            fallback: nil,
            assigns: %{}

  alias Bodyguard.Action

  @type job :: (action :: t -> any)
  @type fallback :: (action :: t -> any)
  @type assigns :: %{atom => any}

  @type t :: %__MODULE__{
          context: module | nil,
          policy: module | nil,
          name: atom | nil,
          user: any,
          auth_run?: boolean,
          auth_result: Bodyguard.Policy.auth_result() | nil,
          authorized?: boolean,
          job: job | nil,
          fallback: fallback | nil,
          assigns: assigns
        }

  @doc """
  Initialize an Action.

  The `context` is assumed to implement `Bodyguard.Policy` callbacks. To
  specify a unique policy, use `put_policy/2`.

  The Action is considered unauthorized by default, until authorization is
  run.
  """
  @spec act(context :: module) :: t
  def act(context) do
    %Action{}
    |> put_context(context)
    |> put_policy(context)
  end

  @doc """
  Change the context.
  """
  @spec put_context(action :: t, context :: module) :: t
  def put_context(%Action{} = action, context) when is_atom(context) do
    %{action | context: context}
  end

  @doc """
  Change the policy.
  """
  @spec put_policy(action :: t, policy :: module) :: t
  def put_policy(%Action{} = action, policy) when is_atom(policy) do
    %{action | policy: policy}
  end

  @doc """
  Change the user to authorize.
  """
  @spec put_user(action :: t, user :: any) :: t
  def put_user(%Action{} = action, user) do
    %{action | user: user}
  end

  @doc """
  Change the job to execute.
  """
  @spec put_job(action :: t, job :: job | nil) :: t
  def put_job(%Action{} = action, job) when is_function(job, 1) or is_nil(job) do
    %{action | job: job}
  end

  @doc """
  Change the fallback handler.
  """
  @spec put_fallback(action :: t, fallback :: fallback | nil) :: t
  def put_fallback(%Action{} = action, fallback)
      when is_function(fallback, 1) or is_nil(fallback) do
    %{action | fallback: fallback}
  end

  @doc """
  Replace the assigns.
  """
  @spec put_assigns(action :: t, assigns :: assigns) :: t
  def put_assigns(%Action{} = action, %{} = assigns) do
    %{action | assigns: assigns}
  end

  @doc """
  Put a new assign.
  """
  @spec assign(action :: t, key :: atom, value :: any) :: t
  def assign(%Action{assigns: assigns} = action, key, value) when is_atom(key) do
    %{action | assigns: Map.put(assigns, key, value)}
  end

  @doc """
  Mark the Action as authorized, regardless of previous authorization.
  """
  @spec force_authorized(action :: t) :: t
  def force_authorized(%Action{} = action) do
    %{action | authorized?: true, auth_result: :ok}
  end

  @doc """
  Mark the Action as unauthorized, regardless of previous authorization.
  """
  @spec force_unauthorized(action :: t, error :: any) :: t
  def force_unauthorized(%Action{} = action, error) do
    %{action | authorized?: false, auth_result: error}
  end

  @doc """
  Use the policy to perform authorization.

  The `opts` are merged in to the Action's `assigns` and passed as the
  `params`.

  See `Bodyguard.permit/3` for details.
  """
  @spec permit(action :: t, name :: atom, opts :: keyword | assigns) :: t

  def permit(action, name, opts \\ [])

  def permit(%Action{policy: nil}, name, _opts) do
    raise RuntimeError, "Policy not specified for #{inspect(name)} action"
  end

  def permit(%Action{auth_run?: true, authorized?: false} = action, _name, _opts) do
    # Don't attempt to auth again, since we already failed
    action
  end

  def permit(%Action{} = action, name, opts) do
    params = Enum.into(opts, action.assigns)

    case Bodyguard.permit(action.policy, name, action.user, params) do
      :ok ->
        %{action | name: name, auth_run?: true, authorized?: true, auth_result: :ok}

      error ->
        %{action | name: name, auth_run?: true, authorized?: false, auth_result: error}
    end
  end

  @doc """
  Same as `authorize/3` but raises on failure.
  """
  @spec permit!(action :: t, name :: atom, opts :: keyword | assigns) :: t

  def permit!(action, name, opts \\ [])

  def permit!(%Action{policy: nil}, name, _opts) do
    raise RuntimeError, "Policy not specified for #{inspect(name)} action"
  end

  def permit!(%Action{auth_run?: true, authorized?: false} = action, _name, _opts) do
    # Don't attempt to auth again, since we already failed
    action
  end

  def permit!(%Action{} = action, name, opts) do
    params = Enum.into(opts, action.assigns)
    Bodyguard.permit!(action.policy, name, action.user, params)
    %{action | name: name, auth_run?: true, authorized?: true, auth_result: :ok}
  end

  @doc """
  Execute the Action's job.

  The `job` must have been previously assigned using `put_job/2`.

  If authorized, the job is run and its value is returned.

  If unauthorized, and a fallback has been provided, the fallback is run and
  its value returned.

  Otherwise, the result of the authorization is returned (something like
  `{:error, reason}`).
  """
  @spec run(action :: t) :: any
  def run(%Action{job: nil}) do
    raise RuntimeError, "Job not specified for action"
  end

  def run(%Action{} = action) do
    cond do
      # Success!
      action.authorized? ->
        action.job.(action)

      # Failure, but with a fallback
      action.fallback ->
        action.fallback.(action)

      # Failure without a fallback
      true ->
        action.auth_result
    end
  end

  @doc """
  Execute the given job.

  If authorized, the job is run and its value is returned.

  If unauthorized, and a fallback has been provided, the fallback is run and
  its value returned.

  Otherwise, the result of the authorization is returned (something like
  `{:error, reason}`).
  """
  @spec run(action :: t, job :: job) :: any
  def run(%Action{} = action, job) when is_function(job, 1) do
    action
    |> put_job(job)
    |> run()
  end

  @doc """
  Execute the given job and fallback.

  If authorized, the job is run and its value is returned.

  If unauthorized, the fallback is run and its value returned.
  """
  @spec run(action :: t, job :: job, fallback :: fallback) :: any
  def run(%Action{} = action, job, fallback)
      when is_function(job, 1) and is_function(fallback, 1) do
    action
    |> put_job(job)
    |> put_fallback(fallback)
    |> run()
  end

  @doc """
  Execute the job, raising on failure.

  The `job` must have been previously assigned using `put_job/2`.
  """
  @spec run!(action :: t) :: any
  def run!(%Action{job: nil}) do
    raise RuntimeError, "Job not specified for action"
  end

  def run!(%Action{} = action) do
    if action.authorized? do
      action.job.(action)
    else
      raise Bodyguard.NotAuthorizedError,
        message: "Not authorized",
        status: 403,
        reason: action.auth_result
    end
  end

  @doc """
  Execute the given job, raising on failure.
  """
  @spec run!(action :: t, job :: job) :: any
  def run!(%Action{} = action, job) when is_function(job, 1) do
    action
    |> put_job(job)
    |> run!()
  end
end
