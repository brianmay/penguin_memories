defmodule PenguinMemoriesWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use PenguinMemoriesWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PenguinMemoriesWeb.ConnCase

      alias PenguinMemoriesWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint PenguinMemoriesWeb.Endpoint

      use PenguinMemoriesWeb, :verified_routes
    end
  end

  setup tags do
    :ok = Sandbox.checkout(PenguinMemories.Repo)

    unless tags[:async] do
      Sandbox.mode(PenguinMemories.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Seed the session with logged-in user claims.
  """
  @spec log_in_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def log_in_user(conn, claims \\ %{"sub" => "user", "name" => "User", "groups" => []}) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:claims, claims)
    |> Plug.Conn.put_session(:live_socket_id, "users_socket:#{claims["sub"]}")
  end
end
