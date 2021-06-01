defmodule PenguinMemoriesWeb.IconHelpers do
  @moduledoc """
  Helper functions to display icon details
  """
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
