defmodule Bodyguard.GeneratorTask do
  @moduledoc false

  defmacro __using__(generator) do
    quote do
      use Mix.Task

      @impl Mix.Task
      def run(args) do
        case Bodyguard.Generators.run(unquote(generator), args) do
          :error ->
            Mix.Task.run("help", [Mix.Task.task_name(__MODULE__)])

          _ ->
            :ok
        end
      end
    end
  end
end
