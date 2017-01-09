defmodule Bodyguard.Policy do
  @moduledoc """
  Behaviour to authorize actions on a particular resource.

  Implement this behaviour for each schema that will be authorized.

  Bodyguard expects this this module to be defined at `MySchema.Policy` unless
  specified otherwise.
  """

  @doc """
  Authorize a user's ability to perform an action on a particular resource.

  To authorize an action, return `true` or `:ok`.

  To deny authorization, return `false`, `:error`, or `{:error, reason}`.
  """
  @callback can?(user :: term, action :: atom, schema :: term) :: boolean | :ok
      | :error | {:error, reason :: term}

  @doc """
  Specify which resources a user can access.

  The result should be a subset of the `scope` argument.
  """
  @callback scope(user :: term, action :: atom, scope :: term) :: term

  @doc """
  Specify which schema attributes a user can modify.
  """
  @callback permitted_attributes(user :: term, schema :: term) :: [atom]

end