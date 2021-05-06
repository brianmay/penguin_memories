defmodule PenguinMemories.Media do
  @moduledoc """
  Perform operations on an media object
  """
  alias PenguinMemories.Media.Maths
  alias PenguinMemories.Media.Tools

  @type t :: %__MODULE__{
          type: String.t(),
          subtype: String.t(),
          path: String.t()
        }
  @enforce_keys [:type, :subtype, :path]
  defstruct [:type, :subtype, :path]

  defmodule Size do
    @moduledoc "An image size in width and height."
    @type t :: %__MODULE__{
            width: integer(),
            height: integer()
          }
    @enforce_keys [:width, :height]
    defstruct [:width, :height]
  end

  defmodule SizeRequirement do
    @moduledoc "Requirement for new image size"
    @type t :: %__MODULE__{
            max_width: integer() | nil,
            max_height: integer() | nil
          }
    @enforce_keys [:max_width, :max_height]
    defstruct [:max_width, :max_height]
  end

  defguardp guard_is_image(type) when type == "image"
  defguardp guard_is_video(type) when type == "video"

  @spec is_image(t()) :: boolean()
  def is_image(%__MODULE__{type: type}), do: guard_is_image(type)

  @spec is_video(t()) :: boolean()
  def is_video(%__MODULE__{type: type}), do: guard_is_video(type)

  @spec is_valid(t()) :: boolean()
  def is_valid(%__MODULE__{} = media), do: is_image(media) or is_video(media)

  @spec validate_media(t()) :: {:ok, t()} | {:error, String.t()}
  def validate_media(%__MODULE__{} = media) do
    cond do
      not is_valid(media) -> {:error, "Invalid media type #{media.type}/#{media.subtype}"}
      not File.exists?(media.path) -> {:error, "File #{media.path} does not exist"}
      true -> {:ok, media}
    end
  end

  @spec get_media(String.t(), String.t() | nil) :: {:ok, t()} | {:error, String.t()}
  def get_media(path, format \\ nil) do
    format =
      case format do
        nil -> MIME.from_path(path)
        format -> format
      end

    [type, subtype] = String.split(format, "/")

    media = %__MODULE__{
      type: type,
      subtype: subtype,
      path: path
    }

    validate_media(media)
  end

  @spec get_format(t()) :: String.t()
  def get_format(%__MODULE__{type: type, subtype: subtype}) do
    "#{type}/#{subtype}"
  end

  @spec get_size(t()) :: Size.t()
  def get_size(%__MODULE__{path: path, type: type, subtype: subtype})
      when guard_is_image(type) and subtype == "cr2" do
    {output, 0} = System.cmd("dcraw", ["-c", path])

    {:ok, fd, file_path} = Temp.open()
    IO.binwrite(fd, output)
    File.close(fd)

    image = Mogrify.open(file_path) |> Mogrify.verbose()

    File.rm(file_path)

    %Size{width: image.width, height: image.height}
  end

  def get_size(%__MODULE__{path: path, type: type}) when guard_is_image(type) do
    image = Mogrify.open(path) |> Mogrify.verbose()
    %Size{width: image.width, height: image.height}
  end

  def get_size(%__MODULE__{path: path, type: type}) when guard_is_video(type) do
    metadata = Tools.ffprobe(path)
    streams = metadata["streams"]
    [video_stream] = Enum.filter(streams, fn stream -> stream["codec_type"] == "video" end)
    %Size{width: video_stream["width"], height: video_stream["height"]}
  end

  @spec get_new_size(t(), SizeRequirement.t()) :: Size.t()
  def get_new_size(%__MODULE__{} = media, %SizeRequirement{} = requirement) do
    max_width = requirement.max_width
    max_height = requirement.max_height

    size = get_size(media)
    width = size.width
    height = size.height

    {width, height} =
      cond do
        is_nil(max_height) ->
          {width, height}

        height > max_height ->
          width = max_height * size.width / size.height
          height = max_height
          {width, height}

        true ->
          {width, height}
      end

    {width, height} =
      cond do
        is_nil(max_width) ->
          {width, height}

        width > max_width ->
          height = max_width * size.height / size.width
          width = max_width
          {width, height}

        true ->
          {width, height}
      end

    width = Maths.round(width, 2)
    height = Maths.round(height, 2)

    %Size{width: width, height: height}
  end

  @spec resize(t(), String.t(), SizeRequirement.t()) :: {:ok, t()} | {:error, String.t()}
  def resize(%__MODULE__{path: path, type: type} = media, new_path, requirement)
      when guard_is_image(type) do
    new_size = get_new_size(media, requirement)
    new_path = "#{new_path}.jpg"

    :ok =
      Thumbnex.create_thumbnail(path, new_path,
        format: "jpeg",
        width: new_size.width,
        height: new_size.height
      )

    # Mogrify.open(path)
    # |> Mogrify.format("jpeg")
    # |> Mogrify.resize("#{new_size.width}x#{new_size.height}")
    # |> Mogrify.save(path: new_path)

    get_media(new_path, "image/jpeg")
  end

  def resize(%__MODULE__{path: path, type: type} = media, new_path, requirement)
      when guard_is_video(type) do
    new_size = get_new_size(media, requirement)
    new_path = "#{new_path}.gif"

    :ok =
      Thumbnex.animated_gif_thumbnail(path, new_path,
        width: new_size.width,
        height: new_size.height
      )

    get_media(new_path, "image/gif")
  end

  @spec get_exif(t()) :: map()
  def get_exif(%__MODULE__{} = media) do
    Tools.exif(media.path)
  end

  @spec get_datetime(t()) :: NaiveDateTime.t()
  def get_datetime(%__MODULE__{} = media) do
    exif = get_exif(media)

    ["EXIF:DateTimeOriginal", "EXIF:DateTimeDigitized", "EXIF:CreateDate"]
    |> Enum.map(fn name -> Map.get(exif, name, nil) end)
    |> Enum.reject(fn value -> is_nil(value) end)
    |> Enum.reject(fn value -> value == "    :  :     :  :  " end)
    |> Enum.map(fn value -> Timex.parse!(value, "%Y:%m:%d %H:%M:%S", :strftime) end)
    |> List.first()
  end

  @spec get_sha256_hash(t()) :: binary()
  def get_sha256_hash(%__MODULE__{} = media) do
    File.stream!(media.path, [], 2_048)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
  end

  @spec get_num_bytes(t()) :: integer()
  def get_num_bytes(%__MODULE__{} = media) do
    %{size: size} = File.stat!(media.path)
    size
  end

  @spec delete(t()) :: :ok | {:error, String.t()}
  def delete(%__MODULE__{} = media) do
    case File.rm(media.path) do
      :ok -> :ok
      {:error, reason} -> {:error, "rm #{media.path} failed: #{inspect(reason)}"}
    end
  end
end