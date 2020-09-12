defmodule PenguinMemories.AccountsTest do
  use PenguinMemories.DataCase

  alias PenguinMemories.Accounts

  describe "users" do
    alias PenguinMemories.Accounts.User

    @valid_attrs %{
      is_admin: true,
      password: "some password",
      password_confirmation: "some password",
      username: "some username",
      name: "some name"
    }
    @update_attrs %{
      is_admin: false,
      username: "some updated username",
      name: "some updated name"
    }
    @invalid_attrs %{
      is_admin: nil,
      username: nil,
      name: nil
    }
    @password_attrs %{
      password: "some other password",
      password_confirmation: "some other password"
    }
    @invalid_password_attrs %{
      password: "some password",
      password_confirmation: "some other password"
    }

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Accounts.create_user()

      user
    end

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
      assert user.is_admin == true
      assert user.username == "some username"
      assert user.name == "some name"
      assert {:ok, user} == Argon2.check_pass(user, "some password", hash_key: :password_hash)
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_user(user, @update_attrs)
      assert user.is_admin == false
      assert user.username == "some updated username"
      assert user.name == "some updated name"
      assert {:ok, user} == Argon2.check_pass(user, "some password", hash_key: :password_hash)
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "update_password/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, %User{} = user} = Accounts.update_password(user, @password_attrs)
      assert {:ok, user} == Argon2.check_pass(user, "some other password", hash_key: :password_hash)
    end

    test "update_password/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_password(user, @invalid_password_attrs)
      assert user == Accounts.get_user!(user.id)
      assert {:ok, user} == Argon2.check_pass(user, "some password", hash_key: :password_hash)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
