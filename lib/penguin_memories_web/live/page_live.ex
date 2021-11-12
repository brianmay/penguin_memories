defmodule PenguinMemoriesWeb.PageLive do
  @moduledoc "Default liveview page"
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.Urls

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(active: "index", page_title: "Index")
      |> assign(query: "", results: %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    url = Urls.parse_url(uri)
    socket = assign(socket, url: url)
    {:noreply, socket}
  end
end
