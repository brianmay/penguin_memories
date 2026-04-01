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

  # Note: Geocalc is used for geofencing calculations

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

  @spec can_see_geo_point(User.t() | nil, {float(), float()} | Geo.Point.t() | nil) :: boolean()
  def can_see_geo_point(_user, nil), do: false

  def can_see_geo_point(user, coordinates) do
    case coordinates do
      # Handle Geo.Point struct (from PostGIS)
      %Geo.Point{coordinates: {lat, lng}} ->
        can_see_coordinates(user, lat, lng)

      # Handle {lat, lng} tuple
      {lat, lng} when is_number(lat) and is_number(lng) ->
        can_see_coordinates(user, lat, lng)

      _ ->
        false
    end
  end

  @spec can_see_coordinates(User.t() | nil, float(), float()) :: boolean()
  defp can_see_coordinates(user, lat, lng) do
    point = %{latitude: lat, longitude: lng}

    private =
      Application.fetch_env!(:penguin_memories, :private_locations)
      |> Enum.any?(fn x -> Geocalc.in_area?(x, point) end)

    # Show if location is not private OR user is logged in
    not private or can_see_latlng(user)
  end
end
