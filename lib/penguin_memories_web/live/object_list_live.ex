defmodule PenguinMemoriesWeb.ObjectListLive do
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.Objects

  @impl true
  def mount(params, _session, socket) do
    type = Objects.get_for_type(params["type"])
    icons = type.get_icons()
    socket = assign(socket, active: params["type"], icons: icons)
    {:ok, socket}
  end
end
