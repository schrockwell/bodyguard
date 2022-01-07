defmodule Bodyguard.Generators do
  @moduledoc false

  def run(module, args) do
    case module.init(args) do
      {:ok, opts} ->
        do_run(module, opts)

      _any ->
        :error
    end
  end

  defp do_run(module, opts) do
    opts
    |> module.run()
    |> Enum.each(&maybe_generate/1)
  end

  defp maybe_generate(%{path: path, content: content}) do
    IO.puts(content)
    IO.puts("")

    prompt =
      if File.exists?(path) do
        "File '#{path}' already exists - overwrite it?"
      else
        "Generate '#{path}'?"
      end

    "#{prompt} [Yn]: "
    |> IO.gets()
    |> String.trim()
    |> case do
      yes when yes in ["Y", "y", ""] ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, content)
        IO.puts("Generated '#{path}'")
        :ok

      _ ->
        :ok
    end
  end
end
