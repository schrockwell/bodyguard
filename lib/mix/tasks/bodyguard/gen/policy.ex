defmodule Mix.Tasks.Bodyguard.Gen.Policy do
  @moduledoc """
  Generates a policy module.

  It expects the policy module as an argument.

  By convention, the module name should end with "Policy", but this is not required.

      $ mix bodyguard.gen.policy POLICY_MODULE [options]

  ## Options

    * `--app` - in umbrella projects, specifies the OTP app name
  """

  @shortdoc "Generates a policy module"

  use Bodyguard.GeneratorTask, Bodyguard.Generators.PolicyGenerator
end
