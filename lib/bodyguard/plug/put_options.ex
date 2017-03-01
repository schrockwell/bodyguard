defmodule Bodyguard.Plug.PutOptions do
  @moduledoc """
  Stores default authorization options.

  Use this to DRY up controllers whose actions have repeated options.

  These defaults are merged in with the `opts` arguments on authorization
  checks that use the `Plug.Conn`.

  You can specify reserved options (like `:policy`), or define your own 
  options which will be converted into params and passed down to the policy module.
  """

  @doc """
  Initializes the Plug.
  """
  def init(opts \\ []), do: opts

  @doc """
  Stores the default options on the `Plug.Conn`.
  """
  def call(conn, opts) do
    Plug.Conn.put_private(conn, :bodyguard_options, opts)
  end
end