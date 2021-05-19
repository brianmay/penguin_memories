defmodule PenguinMemoriesWeb.IncludeView do
  use PenguinMemoriesWeb, :view

  alias PenguinMemories.Database.Query.Icon

  @spec icon_classes(list(String.t()), PenguinMemories.Database.Query.Icon.t()) :: String.t()
  def icon_classes(classes, %Icon{} = icon) do
    results = ["photo_item" | classes]

    case icon.action do
      "D" -> ["removed" | results]
      "R" -> ["regenerate" | results]
      _ -> results
    end
    |> Enum.join(" ")
  end
end
