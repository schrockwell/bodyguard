defmodule Mix.Tasks.Bodyguard.Gen.Plug do
  @moduledoc """
  Generates a Plug authorization module for a Phoenix application.

  It expects the Plug module as an argument, e.g. `MyAppWeb.Plugs.Authorize`.

      $ mix bodyguard.gen.plug PLUG_MODULE

  See the moduledoc of the generated module for usage details.

  ## Options

    * `--app` - in umbrella projects, specifies the OTP app name
  """

  @shortdoc "Generates a Plug authorization module"

  use Bodyguard.GeneratorTask, Bodyguard.Generators.PlugGenerator
end
