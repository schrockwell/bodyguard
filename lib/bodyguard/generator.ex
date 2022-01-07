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

  def module_to_path(app, module) when is_binary(app) do
    unless Mix.Project.umbrella?() do
      raise ArgumentError, "The `--app` switch can only be specified in umbrella projects"
    end

    app = String.to_atom(app)
    app_path = Map.fetch!(Mix.Project.apps_paths(), app)

    Path.join(app_path, module_to_path(nil, module))
  end

  def module_to_path(nil, module) do
    parts =
      module
      |> Module.split()
      |> Enum.map(&Macro.underscore/1)

    dirs = Enum.slice(parts, 0..-2)
    filename = List.last(parts) <> ".ex"

    Path.join(["lib"] ++ dirs ++ [filename])
  end

  def ensure_destination_app(switches) do
    if Mix.Project.umbrella?() and not Keyword.has_key?(switches, :app) do
      IO.warn("The `--app` switch must be specified for umbrella apps", [])
      :error
    else
      :ok
    end
  end

  defp template_path(env, filename) do
    env.file |> Path.dirname() |> Path.join(filename <> ".eex")
  end
end
