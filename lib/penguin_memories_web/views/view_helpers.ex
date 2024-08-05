defmodule PenguinMemoriesWeb.ViewHelpers do
  @moduledoc """
  Helpers for all live modules.
  """
  alias PenguinMemories.Database.Query.Icon

  @spec prepend_if(list :: list(), condition :: bool(), item :: any()) :: list()
  def prepend_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end

  @spec lazy_prepend_list_if(list :: list(), condition :: bool(), item :: (-> list())) ::
          list()
  def lazy_prepend_list_if(list, false, _list_func) do
    list
  end

  def lazy_prepend_list_if(list, true, list_func) do
    items = list_func.()

    Enum.reduce(items, list, fn item, list ->
      [item | list]
    end)
  end

  @spec prepend_list_if(list :: list(), condition :: bool(), items :: list()) :: list()
  def prepend_list_if(list, false, _items) do
    list
  end

  def prepend_list_if(list, true, items) do
    Enum.reduce(items, list, fn item, list ->
      [item | list]
    end)
  end

  @spec icon_classes(Icon.t()) :: list(String.t())
  def icon_classes(%Icon{} = icon) do
    case icon.action do
      "D" -> ["removed"]
      "R" -> ["regenerate"]
      _ -> []
    end
  end
end
