defmodule PenguinMemoriesWeb.LayoutView do
  use PenguinMemoriesWeb, :html

  def link_class(active, item) do
    ["nav-link"]
    |> prepend_if(active == item, "active")
    |> Enum.join(" ")
  end
end
