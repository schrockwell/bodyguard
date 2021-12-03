defmodule PolicyTest do
  use ExUnit.Case, async: false

  defmodule TestPolicy do
    use Bodyguard.Policy

    def permit?(_actor, :fail, _context), do: false
    def permit?(_actor, :succeed, _context), do: true
  end

  defmodule AlwaysTruePolicy do
    @behaviour Bodyguard.Policy

    def permit?(_actor, _action, _context), do: true
  end

  defmodule FalseFallbackPolicy do
    use Bodyguard.Policy, fallback_to: false

    def permit?(_actor, :fail, _context), do: false
    def permit?(_actor, :succeed, _context), do: true
  end

  defmodule DeferToFallbackPolicy do
    use Bodyguard.Policy, fallback_to: AlwaysTruePolicy

    def permit?(_actor, :fail, _context), do: false
    def permit?(_actor, :succeed, _context), do: true
  end

  describe "a regular policy" do
    test "returns true on permit?/3 success" do
      assert TestPolicy.permit?(:user, :succeed, %{})
      assert Bodyguard.permit?(TestPolicy, :user, :succeed, %{})
    end

    test "returns false on permit?/3 failure" do
      refute TestPolicy.permit?(:user, :fail, %{})
      refute Bodyguard.permit?(TestPolicy, :user, :fail, %{})
    end

    test "returns the actor on permit!/3 success" do
      assert :user = TestPolicy.permit!(:user, :succeed, %{})
      assert :user = Bodyguard.permit!(TestPolicy, :user, :succeed, %{})
    end

    test "raises NotAuthorizedError on permit!/3 failure" do
      assert_raise Bodyguard.NotAuthorizedError, fn ->
        TestPolicy.permit!(:user, :fail, %{})
      end

      assert_raise Bodyguard.NotAuthorizedError, fn ->
        Bodyguard.permit!(TestPolicy, :user, :fail, %{})
      end
    end
  end

  describe "a policy with a fallback value" do
    test "defaults to the fallback value" do
      assert FalseFallbackPolicy.permit?(:user, :succeed, %{})
      refute FalseFallbackPolicy.permit?(:user, :fail, %{})
      refute FalseFallbackPolicy.permit?(:user, :flollop, %{})

      assert_raise Bodyguard.NotAuthorizedError, fn ->
        FalseFallbackPolicy.permit!(:user, :flollop, %{})
      end
    end
  end

  describe "a policy with a fallback module" do
    test "defaults to the fallback value" do
      assert DeferToFallbackPolicy.permit?(:user, :succeed, %{})
      refute DeferToFallbackPolicy.permit?(:user, :fail, %{})
      assert DeferToFallbackPolicy.permit?(:user, :flollop, %{})

      DeferToFallbackPolicy.permit!(:user, :flollop, %{})
    end
  end
end
