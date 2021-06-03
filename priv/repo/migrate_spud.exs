require Stream
import Ecto.Query
alias PenguinMemories.Database.Index
alias PenguinMemories.Photos.Album
alias PenguinMemories.Photos.Category
alias PenguinMemories.Photos.File
alias PenguinMemories.Photos.Photo
alias PenguinMemories.Photos.Person
alias PenguinMemories.Photos.Place
alias PenguinMemories.Photos.PhotoAlbum
alias PenguinMemories.Photos.PhotoCategory
alias PenguinMemories.Photos.PhotoPerson
alias PenguinMemories.Media
alias PenguinMemories.Repo
alias PenguinMemories.Storage
alias PenguinMemories.Upload

defmodule Util do
  @spec s(String.t() | nil) :: String.t() | nil
  def s(""), do: nil
  def s(nil), do: nil
  def s(string), do: string

  @spec d(String.t() | nil, String.t()) :: String.t() | nil
  def d("", default), do: default
  def d(nil, default), do: default
  def d(string), do: string

  @spec f(String.t(), (String.t() | nil -> String.t() | nil)) :: String.t() | nil
  def f("", _), do: nil
  def f(nil, _), do: nil
  def f(string, format), do: format.(string)
end

defmodule ImportPhotos do
  import Util

  @spec import_all :: :ok
  def import_all do
    columns = [
      :id,
      :comment,
      :rating,
      :datetime,
      :utc_offset,
      :title,
      :description,
      :path,
      :name,
      :action,
      :view
    ]

    from("spud_photo", select: ^columns, order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn photo ->
      %Photo{
        id: photo.id,
        name: s(photo.title),
        description: s(photo.description),
        private_notes: s(photo.comment),
        rating: photo.rating,
        datetime: f(photo.datetime, fn v -> DateTime.truncate(v, :second) end),
        utc_offset: photo.utc_offset,
        dir: s(photo.path),
        filename: s(photo.name),
        action: "R",
        view: s(photo.view)
      }
    end)
    |> Stream.each(fn photo -> Repo.insert!(photo) end)
    |> Stream.run()
  end

  @spec fix_references :: :ok
  def fix_references do
    from(sp in "spud_photo",
      join: p in Photo,
      on: sp.id == p.id,
      select:
        {%{
           photographer_id: sp.photographer_id,
           place_id: sp.place_id
         }, p},
      order_by: p.id
    )
    |> Repo.stream()
    |> Stream.each(fn {src, photo} ->
      photo
      |> Ecto.Changeset.change(
        photographer_id: src.photographer_id,
        place_id: src.place_id
      )
      |> Repo.update!()
    end)
    |> Stream.run()
  end
end

defmodule ImportPhotoFiles do
  import Util

  @spec import_all :: :ok
  def import_all do
    from(spf in "spud_photo_file",
      join: p in Photo,
      on: spf.photo_id == p.id,
      select:
        {%{
           id: spf.id,
           size_key: spf.size_key,
           width: spf.width,
           height: spf.height,
           mime_type: spf.mime_type,
           dir: spf.dir,
           filename: spf.name,
           is_video: spf.is_video,
           sha256_hash: spf.sha256_hash,
           num_bytes: spf.num_bytes,
           photo_id: spf.photo_id
         }, p},
      order_by: [spf.photo_id, spf.id],
      where: size_key == "orig"
    )
    |> Repo.stream()
    |> Stream.each(fn {src, photo} ->
      path = Storage.build_path(src.dir, src.filename)
      {:ok, media} = Media.get_media(path, src.mime_type)

      true = Media.get_num_bytes(media) == src.num_bytes
      true = Media.get_sha256_hash(media) == src.sha256_hash

      if src.size_key == "orig" do
        new_photo = Upload.add_exif_to_photo(photo, media)

        photo
        |> Ecto.Changeset.change(
          aperture: new_photo.aperture,
          flash_used: new_photo.flash_used,
          metering_mode: new_photo.metering_mode,
          ccd_width: new_photo.ccd_width,
          iso_equiv: new_photo.iso_equiv,
          focal_length: new_photo.focal_length,
          exposure_time: new_photo.exposure_time,
          camera_make: new_photo.camera_make,
          camera_model: new_photo.camera_model,
          focus_dist: new_photo.focus_dist
        )
        |> Repo.update!()
      end

      %File{
        size_key: src.size_key,
        width: src.width,
        height: src.height,
        mime_type: src.mime_type,
        dir: src.dir,
        filename: src.filename,
        is_video: src.is_video,
        sha256_hash: src.sha256_hash,
        num_bytes: src.num_bytes,
        photo_id: src.photo_id
      }
      |> Repo.insert!()
    end)
    |> Stream.run()
  end
end

defmodule ImportAlbums do
  import Util

  @spec import_all :: :ok
  def import_all do
    columns = [:id, :title, :revised, :description, :cover_photo_id]

    from("spud_album", select: ^columns, order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn album ->
      %Album{
        id: album.id,
        name: s(album.title),
        revised: f(album.revised, fn v -> DateTime.truncate(v, :second) end),
        description: s(album.description),
        cover_photo_id: album.cover_photo_id
      }
    end)
    |> Stream.each(fn album -> Repo.insert!(album) end)
    |> Stream.run()

    from(sa in "spud_album",
      join: a in Album,
      on: sa.id == a.id,
      select:
        {%{
           parent_id: sa.parent_id
         }, a},
      order_by: sa.id
    )
    |> Repo.stream()
    |> Stream.each(fn {src, album} ->
      album
      |> Ecto.Changeset.change(parent_id: src.parent_id)
      |> Repo.update!()
    end)
    |> Stream.run()

    from(a in Album, select: a.id, order_by: :id)
    |> Repo.stream()
    |> Stream.scan(%{}, fn id, cache ->
      Index.fix_index(id, Album, cache)
    end)
    |> Stream.run()

    from("spud_photo_album", select: [:album_id, :photo_id], order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn pa ->
      %PhotoAlbum{
        photo_id: pa.photo_id,
        album_id: pa.album_id
      }
    end)
    |> Stream.each(fn pa -> Repo.insert!(pa) end)
    |> Stream.run()
  end
end

defmodule ImportCategorys do
  import Util

  @spec import_all :: :ok
  def import_all do
    columns = [:id, :title, :description, :cover_photo_id]

    from("spud_category", select: ^columns, order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn category ->
      %Category{
        id: category.id,
        name: s(category.title),
        description: s(category.description),
        cover_photo_id: category.cover_photo_id
      }
    end)
    |> Stream.each(fn category -> Repo.insert!(category) end)
    |> Stream.run()

    from(sc in "spud_category",
      join: c in Category,
      on: sc.id == c.id,
      select:
        {%{
           parent_id: sc.parent_id
         }, c},
      order_by: sc.id
    )
    |> Repo.stream()
    |> Stream.each(fn {src, category} ->
      category
      |> Ecto.Changeset.change(parent_id: src.parent_id)
      |> Repo.update!()
    end)
    |> Stream.run()

    from(c in Category, select: c.id, order_by: :id)
    |> Repo.stream()
    |> Stream.scan(%{}, fn id, cache ->
      Index.fix_index(id, Category, cache)
    end)
    |> Stream.run()

    from("spud_photo_category", select: [:category_id, :photo_id], order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn pc ->
      %PhotoCategory{
        photo_id: pc.photo_id,
        category_id: pc.category_id
      }
    end)
    |> Stream.each(fn pc -> Repo.insert!(pc) end)
    |> Stream.run()
  end
end

defmodule ImportPersons do
  import Util

  @spec import_all :: :ok
  def import_all do
    columns = [
      :id,
      :first_name,
      :middle_name,
      :last_name,
      :work_id,
      :dob,
      :dod,
      :email,
      :home_id,
      :called,
      :description,
      :notes,
      :cover_photo_id
    ]

    from("spud_person", select: ^columns, order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn person ->
      name =
        [s(person.first_name), s(person.middle_name), s(person.last_name)]
        |> Enum.reject(fn v -> is_nil(v) end)
        |> Enum.join(" ")

      sort_name =
        case s(person.last_name) do
          nil -> name
          last_name -> last_name
        end

      %Person{
        name: name,
        date_of_birth: person.dob,
        private_notes: s(person.notes),
        work_id: person.work_id,
        date_of_death: person.dod,
        email: person.email,
        cover_photo_id: person.cover_photo_id,
        id: person.id,
        home_id: person.home_id,
        called: s(person.called),
        sort_name: sort_name,
        description: s(person.description)
      }
    end)
    |> Stream.each(fn person -> Repo.insert!(person) end)
    |> Stream.run()

    from(sp in "spud_person",
      join: p in Person,
      on: sp.id == p.id,
      select:
        {%{
           mother_id: sp.mother_id,
           father_id: sp.father_id,
           spouse_id: sp.spouse_id
         }, p},
      order_by: sp.id
    )
    |> Repo.stream()
    |> Stream.each(fn {src, person} ->
      person
      |> Ecto.Changeset.change(
        mother_id: src.mother_id,
        father_id: src.father_id,
        spouse_id: src.spouse_id
      )
      |> Repo.update!()
    end)
    |> Stream.run()

    from(p in Person, select: p.id, order_by: :id)
    |> Repo.stream()
    |> Stream.scan(%{}, fn id, cache ->
      Index.fix_index(id, Person, cache)
    end)
    |> Stream.run()


    from("spud_photo_person", select: [:person_id, :photo_id, :position], order_by: [:photo_id, :position, :id])
    |> Repo.stream()
    |> Stream.scan(nil, fn
      pp, nil -> %{pp | position: 1}
      %{photo_id: photo_id} = pp, %{photo_id: photo_id, position: position} -> %{pp | position: position + 1}
      pp, _ -> %{pp | position: 1}
    end)
    |> Stream.map(fn pp ->
      %PhotoPerson{
        photo_id: pp.photo_id,
        person_id: pp.person_id,
        position: pp.position
      }
    end)
    |> Stream.each(fn pp -> Repo.insert!(pp) end)
    |> Stream.run()
  end
end

defmodule ImportPlaces do
  import Util

  @spec import_all :: :ok
  def import_all do
    columns = [
      :id,
      :title,
      :url,
      :postcode,
      :country,
      :address,
      :address2,
      :state,
      :description,
      :notes,
      :cover_photo_id
    ]

    from("spud_place", select: ^columns, order_by: :id)
    |> Repo.stream()
    |> Stream.map(fn place ->
      %Place{
        id: place.id,
        name: s(place.title),
        postcode: s(place.postcode),
        url: s(place.url),
        description: s(place.description),
        private_notes: s(place.notes),
        address: s(place.address),
        address2: s(place.address2),
        country: s(place.country),
        postcode: s(place.postcode),
        state: s(place.state),
        cover_photo_id: place.cover_photo_id
      }
    end)
    |> Stream.each(fn place -> Repo.insert!(place) end)
    |> Stream.run()

    from(sp in "spud_place",
      join: p in Place,
      on: sp.id == p.id,
      select:
        {%{
           parent_id: sp.parent_id
         }, p},
      order_by: sp.id
    )
    |> Repo.stream()
    |> Stream.each(fn {src, place} ->
      place
      |> Ecto.Changeset.change(parent_id: src.parent_id)
      |> Repo.update!()
    end)
    |> Stream.run()

    from(p in Place, select: p.id, order_by: :id)
    |> Repo.stream()
    |> Stream.scan(%{}, fn id, cache ->
      Index.fix_index(id, Place, cache)
    end)
    |> Stream.run()

    # from("spud_photo_place", select: [:place_id, :photo_id], order_by: :id)
    # |> Repo.stream()
    # |> Stream.map(fn pa ->
    #   %PhotoPlace{
    #     photo_id: pa.photo_id,
    #     place_id: pa.place_id
    #   }
    # end)
    # |> Stream.each(fn pa -> Repo.insert!(pa) end)
    # |> Stream.run()
  end
end

Repo.transaction(
  fn ->
    ImportPhotos.import_all()
    ImportPhotoFiles.import_all()
    ImportAlbums.import_all()
    ImportCategorys.import_all()
    ImportPlaces.import_all()
    ImportPersons.import_all()
    ImportPhotos.fix_references()
  end,
  timeout: :infinity
)

Ecto.Adapters.SQL.query!(Repo, "SELECT setval('pm_photo_id_seq', max(id)) FROM pm_photo;")
Ecto.Adapters.SQL.query!(Repo, "SELECT setval('pm_album_id_seq', max(id)) FROM pm_album;")
Ecto.Adapters.SQL.query!(Repo, "SELECT setval('pm_category_id_seq', max(id)) FROM pm_category;")
Ecto.Adapters.SQL.query!(Repo, "SELECT setval('pm_place_id_seq', max(id)) FROM pm_place;")
Ecto.Adapters.SQL.query!(Repo, "SELECT setval('pm_person_id_seq', max(id)) FROM pm_person;")
