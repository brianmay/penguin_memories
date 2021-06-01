defmodule PenguinMemoriesWeb.IconHelpers do
  alias PenguinMemories.Database.Query.Icon

  @spec icon_classes(Icon.t()) :: String.t()
  def icon_classes(%Icon{} = icon) do
    case icon.action do
      "D" -> ["removed"]
      "R" -> ["regenerate"]
      _ -> []
    end
    |> Enum.join(" ")
  end
end
