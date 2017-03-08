defmodule SchemaTest do
  use ExUnit.Case, async: true

  defmodule MySchema do
    use Bodyguard.Schema
    defstruct []

    def scope(_query, _user, _params) do
      :scoped_query
    end
  end

  defmodule MyOtherSchema do
    use Bodyguard.Schema, scope_with: MyOtherSchema.Query
  end

  defmodule MyOtherSchema.Query do
    def scope(_query, _user, _params) do
      :other_scoped_query
    end
  end

  test "scoping using helpers" do
    assert :scoped_query == Bodyguard.Schema.scope(MySchema,         :user, param: :value)
    assert :scoped_query == Bodyguard.Schema.scope([%MySchema{}],    :user, param: :value)
    assert :scoped_query == Bodyguard.Schema.scope(
      %{__struct__: Ecto.Query, from: {"my_schemas", MySchema}},     :user, param: :value)
    assert_raise ArgumentError, fn -> Bodyguard.Schema.scope("fail", :user, param: :value) end
  end

  test "scoping using callback directly" do
    assert :scoped_query == MySchema.scope(MySchema, :user, param: :value)
  end

  test "scoping using an external module" do
    assert :other_scoped_query == MyOtherSchema.scope(MyOtherSchema, :user)
    assert :other_scoped_query == Bodyguard.Schema.scope(MyOtherSchema, :user)
  end
end