defmodule PenguinMemories.Format do
  @moduledoc """
  Format database values for display.
  """
  @spec display_datetime_offset(datetime :: DateTime.t() | nil, offset :: integer | nil) ::
          String.t() | nil
  def display_datetime_offset(nil, _), do: nil

  def display_datetime_offset(%DateTime{} = datetime, nil) do
    display_datetime_offset(datetime, 0)
  end

  def display_datetime_offset(%DateTime{} = datetime, offset) do
    offset = offset * 60
    datetime = DateTime.add(datetime, offset)
    datetime = %{datetime | utc_offset: offset}
    DateTime.to_string(datetime)
  end

  @spec display_datetime(datetime :: DateTime.t() | nil) :: String.t() | nil
  def display_datetime(nil), do: nil

  def display_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Australia/Melbourne")
    |> DateTime.to_string()
  end
end
