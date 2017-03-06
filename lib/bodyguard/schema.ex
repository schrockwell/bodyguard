defmodule Bodyguard.Schema do
  @moduledoc """
  TODO
  """

  @type params :: %{atom => any}

  @doc """
  TODO
  """
  @callback scope(query :: any, user :: any, params :: params) :: any

  @doc """
  TODO
  """
  def scope(query, user, opts \\ []) do
    params = Enum.into(opts, %{})
    {params, schema} = Map.pop(params, :schema, resolve_schema(query))
    
    apply(schema, :scope, [query, user, params])
  end

  # Private

  # Ecto query (this feels dirty...)
  defp resolve_schema(%{__struct__: Ecto.Query, from: {_source, schema}})
    when is_atom(schema), do: schema

  # List of structs
  defp resolve_schema([%{__struct__: schema} | _rest]), do: schema

  # Schema module itself
  defp resolve_schema(schema) when is_atom(schema), do: schema

  # Unable to determine
  defp resolve_schema(unknown) do
    raise ArgumentError, "Cannot automatically determine the schema of
      #{inspect(unknown)} - specify the :schema option"
  end
end