defmodule Mix.Tasks.Bodyguard.Gen.Policy do
  @moduledoc """
  Generates a policy module.

  It expects the policy module name as an argument.

  By convention, the module name should end with "Policy", but this is not required.

      $ mix bodyguard.gen.policy MODULE

  ## Options

  None, at the moment!
  """

  @shortdoc "Generates a policy module"

  use Bodyguard.GeneratorTask, Bodyguard.Generators.PolicyGenerator
end
