defmodule PenguinMemories.Photos do
  @moduledoc """
  The Photos context.
  """

  import Ecto.Query, warn: false
  alias PenguinMemories.Repo

  alias PenguinMemories.Photos.Album

  @doc """
  Returns the list of albums.

  ## Examples

      iex> list_albums()
      [%Album{}, ...]

  """
  def list_albums do
    Repo.all(Album)
  end

  @doc """
  Gets a single album.

  Raises `Ecto.NoResultsError` if the Album does not exist.

  ## Examples

      iex> get_album!(123)
      %Album{}

      iex> get_album!(456)
      ** (Ecto.NoResultsError)

  """
  def get_album!(id), do: Repo.get!(Album, id)

  @doc """
  Creates a album.

  ## Examples

      iex> create_album(%{field: value})
      {:ok, %Album{}}

      iex> create_album(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_album(attrs \\ %{}) do
    %Album{}
    |> Album.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a album.

  ## Examples

      iex> update_album(album, %{field: new_value})
      {:ok, %Album{}}

      iex> update_album(album, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_album(%Album{} = album, attrs) do
    album
    |> Album.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a album.

  ## Examples

      iex> delete_album(album)
      {:ok, %Album{}}

      iex> delete_album(album)
      {:error, %Ecto.Changeset{}}

  """
  def delete_album(%Album{} = album) do
    Repo.delete(album)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking album changes.

  ## Examples

      iex> change_album(album)
      %Ecto.Changeset{data: %Album{}}

  """
  def change_album(%Album{} = album, attrs \\ %{}) do
    Album.changeset(album, attrs)
  end

  alias PenguinMemories.Photos.Photo

  @doc """
  Returns the list of photo.

  ## Examples

      iex> list_photo()
      [%Photo{}, ...]

  """
  def list_photo do
    Repo.all(Photo)
  end

  @doc """
  Gets a single photo.

  Raises `Ecto.NoResultsError` if the Photo does not exist.

  ## Examples

      iex> get_photo!(123)
      %Photo{}

      iex> get_photo!(456)
      ** (Ecto.NoResultsError)

  """
  def get_photo!(id), do: Repo.get!(Photo, id)

  @doc """
  Creates a photo.

  ## Examples

      iex> create_photo(%{field: value})
      {:ok, %Photo{}}

      iex> create_photo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_photo(attrs \\ %{}) do
    %Photo{}
    |> Photo.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a photo.

  ## Examples

      iex> update_photo(photo, %{field: new_value})
      {:ok, %Photo{}}

      iex> update_photo(photo, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_photo(%Photo{} = photo, attrs) do
    photo
    |> Photo.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a photo.

  ## Examples

      iex> delete_photo(photo)
      {:ok, %Photo{}}

      iex> delete_photo(photo)
      {:error, %Ecto.Changeset{}}

  """
  def delete_photo(%Photo{} = photo) do
    Repo.delete(photo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking photo changes.

  ## Examples

      iex> change_photo(photo)
      %Ecto.Changeset{data: %Photo{}}

  """
  def change_photo(%Photo{} = photo, attrs \\ %{}) do
    Photo.changeset(photo, attrs)
  end

  alias PenguinMemories.Photos.Thumb

  @doc """
  Returns the list of thumb.

  ## Examples

      iex> list_thumb()
      [%Thumb{}, ...]

  """
  def list_thumb do
    Repo.all(Thumb)
  end

  @doc """
  Gets a single thumb.

  Raises `Ecto.NoResultsError` if the Thumb does not exist.

  ## Examples

      iex> get_thumb!(123)
      %Thumb{}

      iex> get_thumb!(456)
      ** (Ecto.NoResultsError)

  """
  def get_thumb!(id), do: Repo.get!(Thumb, id)

  @doc """
  Creates a thumb.

  ## Examples

      iex> create_thumb(%{field: value})
      {:ok, %Thumb{}}

      iex> create_thumb(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_thumb(attrs \\ %{}) do
    %Thumb{}
    |> Thumb.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a thumb.

  ## Examples

      iex> update_thumb(thumb, %{field: new_value})
      {:ok, %Thumb{}}

      iex> update_thumb(thumb, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_thumb(%Thumb{} = thumb, attrs) do
    thumb
    |> Thumb.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a thumb.

  ## Examples

      iex> delete_thumb(thumb)
      {:ok, %Thumb{}}

      iex> delete_thumb(thumb)
      {:error, %Ecto.Changeset{}}

  """
  def delete_thumb(%Thumb{} = thumb) do
    Repo.delete(thumb)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking thumb changes.

  ## Examples

      iex> change_thumb(thumb)
      %Ecto.Changeset{data: %Thumb{}}

  """
  def change_thumb(%Thumb{} = thumb, attrs \\ %{}) do
    Thumb.changeset(thumb, attrs)
  end

  alias PenguinMemories.Photos.Video

  @doc """
  Returns the list of videos.

  ## Examples

      iex> list_videos()
      [%Video{}, ...]

  """
  def list_videos do
    Repo.all(Video)
  end

  @doc """
  Gets a single video.

  Raises `Ecto.NoResultsError` if the Video does not exist.

  ## Examples

      iex> get_video!(123)
      %Video{}

      iex> get_video!(456)
      ** (Ecto.NoResultsError)

  """
  def get_video!(id), do: Repo.get!(Video, id)

  @doc """
  Creates a video.

  ## Examples

      iex> create_video(%{field: value})
      {:ok, %Video{}}

      iex> create_video(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_video(attrs \\ %{}) do
    %Video{}
    |> Video.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a video.

  ## Examples

      iex> update_video(video, %{field: new_value})
      {:ok, %Video{}}

      iex> update_video(video, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_video(%Video{} = video, attrs) do
    video
    |> Video.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a video.

  ## Examples

      iex> delete_video(video)
      {:ok, %Video{}}

      iex> delete_video(video)
      {:error, %Ecto.Changeset{}}

  """
  def delete_video(%Video{} = video) do
    Repo.delete(video)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking video changes.

  ## Examples

      iex> change_video(video)
      %Ecto.Changeset{data: %Video{}}

  """
  def change_video(%Video{} = video, attrs \\ %{}) do
    Video.changeset(video, attrs)
  end

  alias PenguinMemories.Photos.File

  @doc """
  Returns the list of files.

  ## Examples

      iex> list_files()
      [%File{}, ...]

  """
  def list_files do
    Repo.all(File)
  end

  @doc """
  Gets a single file.

  Raises `Ecto.NoResultsError` if the File does not exist.

  ## Examples

      iex> get_file!(123)
      %File{}

      iex> get_file!(456)
      ** (Ecto.NoResultsError)

  """
  def get_file!(id), do: Repo.get!(File, id)

  @doc """
  Creates a file.

  ## Examples

      iex> create_file(%{field: value})
      {:ok, %File{}}

      iex> create_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_file(attrs \\ %{}) do
    %File{}
    |> File.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a file.

  ## Examples

      iex> update_file(file, %{field: new_value})
      {:ok, %File{}}

      iex> update_file(file, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_file(%File{} = file, attrs) do
    file
    |> File.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a file.

  ## Examples

      iex> delete_file(file)
      {:ok, %File{}}

      iex> delete_file(file)
      {:error, %Ecto.Changeset{}}

  """
  def delete_file(%File{} = file) do
    Repo.delete(file)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking file changes.

  ## Examples

      iex> change_file(file)
      %Ecto.Changeset{data: %File{}}

  """
  def change_file(%File{} = file, attrs \\ %{}) do
    File.changeset(file, attrs)
  end

  alias PenguinMemories.Photos.AlbumAscendant

  @doc """
  Returns the list of album_ascendant.

  ## Examples

      iex> list_album_ascendant()
      [%AlbumAscendant{}, ...]

  """
  def list_album_ascendant do
    Repo.all(AlbumAscendant)
  end

  @doc """
  Gets a single album_ascendant.

  Raises `Ecto.NoResultsError` if the Album ascendant does not exist.

  ## Examples

      iex> get_album_ascendant!(123)
      %AlbumAscendant{}

      iex> get_album_ascendant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_album_ascendant!(id), do: Repo.get!(AlbumAscendant, id)

  @doc """
  Creates a album_ascendant.

  ## Examples

      iex> create_album_ascendant(%{field: value})
      {:ok, %AlbumAscendant{}}

      iex> create_album_ascendant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_album_ascendant(attrs \\ %{}) do
    %AlbumAscendant{}
    |> AlbumAscendant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a album_ascendant.

  ## Examples

      iex> update_album_ascendant(album_ascendant, %{field: new_value})
      {:ok, %AlbumAscendant{}}

      iex> update_album_ascendant(album_ascendant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_album_ascendant(%AlbumAscendant{} = album_ascendant, attrs) do
    album_ascendant
    |> AlbumAscendant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a album_ascendant.

  ## Examples

      iex> delete_album_ascendant(album_ascendant)
      {:ok, %AlbumAscendant{}}

      iex> delete_album_ascendant(album_ascendant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_album_ascendant(%AlbumAscendant{} = album_ascendant) do
    Repo.delete(album_ascendant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking album_ascendant changes.

  ## Examples

      iex> change_album_ascendant(album_ascendant)
      %Ecto.Changeset{data: %AlbumAscendant{}}

  """
  def change_album_ascendant(%AlbumAscendant{} = album_ascendant, attrs \\ %{}) do
    AlbumAscendant.changeset(album_ascendant, attrs)
  end
end
