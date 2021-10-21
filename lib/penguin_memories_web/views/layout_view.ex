defmodule PenguinMemoriesWeb.LayoutView do
  use PenguinMemoriesWeb, :view

  def item_class(active, item) do
    ["nav-item"]
    |> prepend_if(active == item, "active")
    |> Enum.join(" ")
  end

  def link_class(active, item) do
    ["nav-link"]
    |> prepend_if(active == item, "active")
    |> Enum.join(" ")
  end
end
