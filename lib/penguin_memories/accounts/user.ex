defmodule PenguinMemories.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
    is_admin: boolean,
    password: String.t(),
    password_confirmation: String.t(),
    password_hash: binary(),
    username: String.t(),
    name: String.t(),
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  schema "users" do
    field :is_admin, :boolean, default: false
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :password_hash, :string
    field :username, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :name, :is_admin, :password, :password_confirmation])
    |> validate_required([:username, :name, :password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> put_password_hash
    |> put_change(:password, nil)
    |> put_change(:password_confirmation, nil)
  end

  @doc false
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :name, :is_admin])
    |> validate_required([:username, :name])
  end

  @doc false
  def login_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
  end

  @doc false
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> put_password_hash
    |> put_change(:password, nil)
    |> put_change(:password_confirmation, nil)
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password_hash: Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
