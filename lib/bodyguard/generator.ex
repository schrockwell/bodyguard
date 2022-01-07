defmodule Bodyguard.Generator do
  @moduledoc false

  @callback init(args :: list) :: {:ok, term} | :error
  @callback run(opts :: term) :: [%{path: String.t(), content: String.t()}]

  defmacro __using__(_opts) do
    quote do
      import Bodyguard.Generator
      require EEx
      @behaviour Bodyguard.Generator
    end
  end

  defmacro include_templates(templates) do
    for {name, args} <- templates do
      render_name = String.to_atom("render_#{name}")
      filename = "#{name}.ex"
      path = template_path(__CALLER__, filename)

      quote do
        EEx.function_from_file(:defp, unquote(render_name), unquote(path), unquote(args))
      end
    end
  end

  def module_to_path(module) do
    parts =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)

    dirs = Enum.slice(parts, 0..-2)
    filename = List.last(parts) <> ".ex"

    Path.join(["lib"] ++ dirs ++ [filename])
  end

  defp template_path(env, filename) do
    env.file |> Path.dirname() |> Path.join(filename <> ".eex")
  end
end
