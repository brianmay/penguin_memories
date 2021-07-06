defmodule PenguinMemories.Repo.Migrations.MigrateAlbumSortName do
  use Ecto.Migration

  import Ecto.Query

  alias PenguinMemories.Repo

  def get_first_photo(album_id) do
    from(pf in "pm_photo_file",
      left_join: p in "pm_photo",
      on: p.id == pf.id,
      left_join: pa in "pm_photo_album",
      on: pa.photo_id == p.id,
      where: pa.album_id == ^album_id,
      select: %{datetime: p.datetime},
      order_by: p.datetime,
      limit: 1
    )
    |> Repo.one()
  end

  def get_year_from_date(string) do
    string
    |> String.split("-", parts: 3)
    |> List.first()
  end

  def get_name(name, photo) do
    {name, sort_name} =
      if String.starts_with?(name, "21") or String.starts_with?(name, "20") or
           String.starts_with?(name, "19") do
        {date, name} =
          case String.split(name, " ", parts: 2) do
            [date, name] -> {date, name}
            [date] -> {date, nil}
          end

        year = get_year_from_date(date)

        name =
          cond do
            name == nil -> nil
            String.contains?(name, year) -> name
            true -> name <> " " <> year
          end

        case name do
          nil -> {date, date}
          name -> {name, date}
        end
      else
        {name, name}
      end

    sort_name =
      if photo == nil do
        sort_name
      else
        photo.datetime
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.shift_zone!("Australia/Victoria")
        |> DateTime.to_date()
        |> Date.to_iso8601()
      end

    {name, sort_name}
  end

  def up do
    {:ok, _} = Application.ensure_all_started(:tzdata)

    from("pm_album", select: [:id, :name], order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn album ->
      photo = get_first_photo(album.id)
      {name, sort_name} = get_name(album.name, photo)

      query =
        from("pm_album",
          where: [id: ^album.id],
          update: [set: [name: ^name, sort_name: ^sort_name]]
        )

      Repo.update_all(query, [])
    end)
    |> Stream.run()

    alter table(:pm_album) do
      modify :sort_name, :string, null: false
    end

    drop(index(:pm_album, [:name, :id]))
    create(index(:pm_album, [:name]))
    create(index(:pm_album, [:sort_name, :name, :id]))
  end

  def down do
    alter table(:pm_album) do
      modify :sort_name, :string, null: true
    end

    create(index(:pm_album, [:name, :id]))
    drop(index(:pm_album, [:name]))
    drop(index(:pm_album, [:sort_name, :name, :id]))
  end
end
