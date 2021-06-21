defmodule PenguinMemoriesWeb.Plug.Static do
  @moduledoc """
  Serve static image files
  """
  def init(default) do
    default = [{:from, Application.get_env(:penguin_memories, :image_dir)} | default]
    Plug.Static.init(default)
  end

  def call(%Plug.Conn{} = conn, default) do
    default = [{:from, Application.get_env(:penguin_memories, :image_dir)} | default]
    Plug.Static.call(conn, default)
  end
end
