defmodule UsingTest do
  use ExUnit.Case, async: true

  defmodule TestBasicPolicy do
    use Bodyguard.Policy

    def permit?(_actor, :fail, _context), do: false
    def permit?(_actor, :succeed, _context), do: true
  end

  defmodule TestNothingInjectedPolicy do
    use Bodyguard.Policy, only: []

    def permit?(_actor, :fail, _context), do: false
    def permit?(_actor, :succeed, _context), do: true
  end

  describe "Bodyguard.__using__/1" do
    test "injects the permit!/3 function" do
      assert {:permit!, 3} in TestBasicPolicy.__info__(:functions)
    end

    test "does not inject functions ecluded with the `:only` option" do
      refute {:permit!, 3} in TestNothingInjectedPolicy.__info__(:functions)
    end

    test "raises ArgumentError if an unknown function is passed to the `:only` option" do
      require Bodyguard.Policy

      assert_raise ArgumentError, fn ->
        defmodule TestPolicy do
          use Bodyguard.Policy, only: [foo: 123]
        end
      end
    end

    test "raises ArgumentError if a bad value is passed to the `:fallback_to` option" do
      require Bodyguard.Policy

      assert_raise ArgumentError, fn ->
        defmodule TestPolicy do
          use Bodyguard.Policy, fallback_to: "boom"
        end
      end

      assert_raise ArgumentError, fn ->
        defmodule TestPolicy do
          use Bodyguard.Policy, fallback_to: __MODULE__
        end
      end
    end
  end
end
