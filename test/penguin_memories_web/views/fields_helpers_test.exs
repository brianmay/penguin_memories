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

    test "escapes injected quotes inside nested markdown link attributes" do
      field = %Field{id: :description, name: "Description", type: :markdown}

      rendered =
        FieldHelpers.output_field(
          nil,
          %{description: ~S|*prefix [click](http://example.com/?a=x" onerror="alert(1))*|},
          field
        )
        |> Phoenix.HTML.safe_to_string()

      assert rendered =~ "<em>"
      assert rendered =~ ~S|href="http://example.com/?a=x&quot; onerror=&quot;alert(1)"|
      refute rendered =~ ~S| onerror="alert(1)"|
    end

    test "escapes quotes in three-tuple ast nodes" do
      node = {"a", [{"href", ~S|http://example.com/?a=x" onerror="alert(1)|}], ["click"]}

      assert {"a", [{"href", escaped_href}], ["click"]} = FieldHelpers.sanitize_markdown_ast(node)
      assert escaped_href == ~S|http://example.com/?a=x&quot; onerror=&quot;alert(1)|
    end

    test "escapes quotes in four-tuple ast nodes" do
      node = {"a", [{"href", ~S|http://example.com/?a=x" onerror="alert(1)|}], ["click"], %{}}

      assert {"a", [{"href", escaped_href}], ["click"], %{}} =
               FieldHelpers.sanitize_markdown_ast(node)

      assert escaped_href == ~S|http://example.com/?a=x&quot; onerror=&quot;alert(1)|
    end

    test "escapes quotes in lists of ast nodes" do
      nodes = [
        {"a", [{"href", ~S|http://example.com/?a=x" onerror="alert(1)|}], ["click"]},
        "tail"
      ]

      assert [
               {"a", [{"href", escaped_href}], ["click"]},
               "tail"
             ] = FieldHelpers.sanitize_markdown_ast(nodes)

      assert escaped_href == ~S|http://example.com/?a=x&quot; onerror=&quot;alert(1)|
    end

    test "leaves unrelated attributes unchanged" do
      node = {"span", [{"class", ~S|note "quoted"|}], ["text"]}

      assert {"span", [{"class", ~S|note "quoted"|}], ["text"]} =
               FieldHelpers.sanitize_markdown_ast(node)
    end
  end
end
