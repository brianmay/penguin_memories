defmodule PenguinMemoriesWeb.FieldHelpersTest do
  use ExUnit.Case, async: true

  alias PenguinMemories.Database.Fields.Field
  alias PenguinMemoriesWeb.FieldHelpers

  describe "output_field/3" do
    test "escapes injected quotes inside markdown link attributes" do
      field = %Field{id: :description, name: "Description", type: :markdown}

      rendered =
        FieldHelpers.output_field(
          nil,
          %{description: ~S|[click](http://example.com/?a=x" onerror="alert(1))|},
          field
        )
        |> Phoenix.HTML.safe_to_string()

      assert rendered =~ ~S|href="http://example.com/?a=x&quot; onerror=&quot;alert(1)"|
      refute rendered =~ ~S| onerror="alert(1)"|
    end
  end
end
