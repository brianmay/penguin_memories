defmodule PenguinMemoriesWeb.SessionControllerTest do
  use PenguinMemoriesWeb.ConnCase

  alias PenguinMemories.Accounts
  alias PenguinMemories.Accounts.Guardian

  def fixture(:user) do
    {:ok, user} =
      Accounts.create_user(%{
        is_admin: false,
        name: "Some Name",
        password: "some password",
        password_confirmation: "some password",
        username: "user"
      })

    user
  end

  def fixture(:token) do
    user = fixture(:user)
    {:ok, token, _} = Guardian.encode_and_sign(user, %{}, token_type: :access)
    token
  end

  describe "anonymous access" do
    setup [:create_user]

    test "login as anonymous", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :login))
      assert html_response(conn, 200) =~ "Login Page"
    end

    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :index))
      response(conn, 302)
    end

    test "new user", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :new))
      response(conn, 302)
    end

    test "create user", %{conn: conn} do
      conn = put(conn, Routes.user_path(conn, :new))
      response(conn, 302)
    end

    test "edit user", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :edit, user))
      response(conn, 302)
    end

    test "update user", %{conn: conn, user: user} do
      conn = put(conn, Routes.user_path(conn, :update, user))
      response(conn, 302)
    end

    test "edit user password", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :password_edit, user))
      response(conn, 302)
    end

    test "update user password", %{conn: conn, user: user} do
      conn = put(conn, Routes.user_path(conn, :password_update, user))
      response(conn, 302)
    end

    test "show user", %{conn: conn, user: user} do
      conn = get(conn, Routes.user_path(conn, :edit, user))
      response(conn, 302)
    end

    test "delete user", %{conn: conn, user: user} do
      conn = delete(conn, Routes.user_path(conn, :delete, user))
      response(conn, 302)
    end
  end

  describe "login" do
    test "as user", %{conn: conn} do
      fixture(:user)

      conn =
        post(conn, Routes.session_path(conn, :login),
          user: %{"username" => "user", "password" => "some password"}
        )

      assert redirected_to(conn) == Routes.page_path(conn, :index)
    end
  end

  describe "logout" do
    test "as user", %{conn: conn} do
      token = fixture(:token)
      conn = put_req_header(conn, "authorization", "bearer: " <> token)

      conn = post(conn, Routes.session_path(conn, :logout))
      assert redirected_to(conn) == Routes.page_path(conn, :index)
    end
  end

  defp create_user(_) do
    user = fixture(:user)
    {:ok, user: user}
  end
end
