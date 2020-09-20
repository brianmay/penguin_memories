defmodule PenguinMemoriesWeb.IncludeView do
  use PenguinMemoriesWeb, :view

  @spec icon_classes(list(String.t), PenguinMemories.Object.Icon.t()) :: String.t()
  def icon_classes(classes, icon) do
    results = ["photo_item" | classes]
    case icon.action do
      "D" -> ["removed" | results]
      "R" -> ["regenerate" | results]
      _ -> results
    end |> Enum.join(" ")
  end

end

