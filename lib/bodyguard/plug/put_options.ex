defmodule Bodyguard.Plug.PutOptions do
  @behaviour Plug
  
  @moduledoc """
  Stores default authorization options.

  Use this to DRY up controllers whose actions have repeated options.

  These defaults are merged in with the `opts` arguments on authorization
  checks that use the `Plug.Conn`.

  You can specify Bodyguard options, or define your own options which will be
  converted into a params map and passed down to the policy.
  """

  @doc false
  def init(opts \\ []), do: opts

  @doc false
  def call(conn, opts) do
    Plug.Conn.put_private(conn, :bodyguard_options, opts)
  end
end