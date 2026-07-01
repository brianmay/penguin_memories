defmodule PenguinMemoriesWeb.AuthTest do
  use PenguinMemoriesWeb.ConnCase

  describe "RequireAuth plug" do
    test "redirects unauthenticated requests to the authorize endpoint", %{conn: conn} do
      conn = get(conn, "/upload")
      assert redirected_to(conn) == "/auth/authorize?state=%2Fupload"
    end

    test "carries the query string in the state param", %{conn: conn} do
      conn = get(conn, "/login?next=/foo")
      assert redirected_to(conn) == "/auth/authorize?state=%2Flogin%3Fnext%3D%2Ffoo"
    end

    test "passes through when logged in", %{conn: conn} do
      conn =
        conn
        |> log_in_user()
        |> get("/login?next=/foo")

      assert redirected_to(conn) == "/foo"
    end
  end

  describe "logout" do
    test "clears the session and redirects", %{conn: conn} do
      conn =
        conn
        |> log_in_user()
        |> post("/logout?next=/albums/")

      assert redirected_to(conn) == "/albums/"
      assert get_session(conn, :claims) == nil
      assert get_session(conn, :live_socket_id) == nil
    end
  end

  describe "callback" do
    test "rejects a callback with no authorization in progress", %{conn: conn} do
      conn = get(conn, "/openid_connect_redirect_uri?code=x&state=y")
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :danger) == "Login failed."
    end
  end

  describe "admin check" do
    test "denies the dashboard to non-admin users", %{conn: conn} do
      conn =
        conn
        |> log_in_user(%{"sub" => "user", "name" => "User", "groups" => []})
        |> get("/dashboard")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :danger) == "You must be admin to access this."
    end
  end
end
