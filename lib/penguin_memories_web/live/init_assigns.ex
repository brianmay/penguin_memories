defmodule PenguinMemoriesWeb.InitAssigns do
  @moduledoc """
  Hook to intercept liveview mount requests
  """
  import Phoenix.LiveView

  def mount(_params, session, socket) do
    user = session["claims"]
    socket = assign(socket, :current_user, user)
    {:cont, socket}
  end
end