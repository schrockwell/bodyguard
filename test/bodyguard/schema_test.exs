defmodule SchemaTest do
  use ExUnit.Case, async: false

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

  defmodule MyWeirdSchema do
    @behaviour Bodyguard.Schema

    def scope(_query, _user, _params) do
      :weird_scoped_query
    end
  end

  defmodule MyOtherSchema.Query do
    def scope(_query, _user, _params) do
      :other_scoped_query
    end
  end

  test "scoping using helpers" do
    assert :scoped_query == Bodyguard.scope(MySchema, :user, param: :value)
    assert :scoped_query == Bodyguard.scope([%MySchema{}], :user, param: :value)

    assert :scoped_query ==
             Bodyguard.scope(
               %{__struct__: Ecto.Query, from: {"my_schemas", MySchema}},
               :user,
               param: :value
             )

    assert_raise ArgumentError, fn -> Bodyguard.scope("fail", :user, param: :value) end
  end

  test "scoping using callback directly" do
    assert :scoped_query == MySchema.scope(MySchema, :user, param: :value)
  end

  test "scoping using an external module with the old syntax" do
    assert :other_scoped_query == Bodyguard.scope(MyOtherSchema, :user)
  end

  test "scoping using an external module as an option" do
    # Old syntax
    assert :weird_scoped_query == Bodyguard.scope(MySchema, :user, schema: MyWeirdSchema)

    # New syntax
    assert :weird_scoped_query ==
      Bodyguard.scope(MySchema, :user, "params", schema: MyWeirdSchema)

    # Make sure a non-queryable is overrridden
    assert :weird_scoped_query == Bodyguard.scope("non-queryable", :user, schema: MyWeirdSchema)
    assert :weird_scoped_query == Bodyguard.scope("non-queryable", :user, "params", schema: MyWeirdSchema)
  end
end
