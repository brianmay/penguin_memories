defmodule PenguinMemoriesWeb.PageLiveTest do
  use PenguinMemoriesWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Welcome to Penguin Memories!"
    assert render(page_live) =~ "Welcome to Penguin Memories!"
  end
end
