defmodule PenguinMemories.Auth do
  @moduledoc """
  Functions that assist with authentication.
  """
  defmodule User do
    @moduledoc """
    Represent a user.
    """
    @type t() :: map()
  end

  @spec user_is_admin?(User.t()) :: boolean()
  def user_is_admin?(user) do
    case user do
      %{"groups" => groups} -> Enum.member?(groups, "admin")
      _ -> false
    end
  end

  @spec can_edit(User.t() | nil) :: boolean
  def can_edit(nil), do: false
  def can_edit(_), do: true

  @spec can_see_private(User.t() | nil) :: boolean
  def can_see_private(nil), do: false
  def can_see_private(_), do: true

  @spec can_see_orig(User.t() | nil) :: boolean
  def can_see_orig(nil), do: false
  def can_see_orig(_), do: true

  @spec can_see_latlng(User.t() | nil) :: boolean
  def can_see_latlng(nil), do: false
  def can_see_latlng(_), do: true
end
