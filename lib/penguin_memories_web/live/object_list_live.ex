defmodule PenguinMemoriesWeb.ObjectListLive do
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.Objects
  alias PenguinMemoriesWeb.Router.Helpers, as: Routes

  @impl true
  def mount(params, _session, socket) do
    assigns = [
      type: params["type"],
      active: params["type"],
      icons: [],
      requested_before_key: nil,
      requested_after_key: nil,
      before_key: nil,
      after_key: nil,
      total_count: 0
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    requested_before_key = params["before"]
    requested_after_key = params["after"]

    type = Objects.get_for_type(params["type"])
    {icons, before_key, after_key, total_count} = type.get_icons(requested_before_key, requested_after_key)

    assigns = [
      type: params["type"],
      active: params["type"],
      icons: icons,
      requested_before_key: params["before"],
      requested_after_key: params["after"],
      before_key: before_key,
      after_key: after_key,
      total_count: total_count
    ]

    {:noreply, assign(socket, assigns)}
  end
end
