defmodule PenguinMemories.Media do
  @moduledoc """
  Perform operations on an media object
  """
  alias File
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
            max_height: integer() | nil,
            format: String.t()
          }
    @enforce_keys [:max_width, :max_height, :format]
    defstruct [:max_width, :max_height, :format]
  end

  defguardp guard_is_image(type) when type == "image"

  defguardp guard_is_raw(type, subtype)
            when guard_is_image(type) and subtype in ["cr2", "x-canon-cr2"]

  defguardp guard_is_video(type) when type == "video"

  defp parse_exif_datetime(value) do
    [date_part, time_part] = String.split(value, " ")
    [y, m, d] = String.split(date_part, ":") |> Enum.map(&String.to_integer/1)
    [h, min, s] = String.split(time_part, ":") |> Enum.map(&String.to_integer/1)
    NaiveDateTime.new!(y, m, d, h, min, s)
  end

  @spec is_image(t()) :: boolean()
  def is_image(%__MODULE__{type: type}), do: guard_is_image(type)

  @spec is_video(t()) :: boolean()
  def is_video(%__MODULE__{type: type}), do: guard_is_video(type)

  @spec is_valid(t()) :: boolean()
  def is_valid(%__MODULE__{} = media), do: is_image(media) or is_video(media)

  @spec validate_media(t()) :: {:ok, t()} | {:error, String.t()}
  def validate_media(%__MODULE__{} = media) do
    cond do
      not is_valid(media) ->
        {:error, "Invalid media type #{media.type}/#{media.subtype} for #{media.path}"}

      not File.exists?(media.path) ->
        {:error, "File #{media.path} does not exist"}

      true ->
        {:ok, media}
    end
  end

  @spec get_media(String.t(), String.t() | nil) :: {:ok, t()} | {:error, String.t()}
  def get_media(path, format \\ nil) do
    format =
      cond do
        format != nil -> format
        true -> MIME.from_path(path)
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

  @spec get_extension(t()) :: String.t()
  def get_extension(%__MODULE__{} = media) do
    media
    |> get_format()
    |> MIME.extensions()
    |> hd()
  end

  @spec dcraw_image(t()) :: t()
  defp dcraw_image(%__MODULE__{path: path, type: type, subtype: subtype})
       when guard_is_raw(type, subtype) do
    {output, 0} = System.cmd("dcraw_emu", ["-Z", "-", path])

    {:ok, fd, file_path} = Temp.open()
    IO.binwrite(fd, output)
    File.close(fd)

    {:ok, new_media} = get_media(file_path, "image/x-portable-bitmap")
    new_media
  end

  @spec get_size(t()) :: Size.t()
  def get_size(%__MODULE__{type: type, subtype: subtype} = media)
      when guard_is_raw(type, subtype) do
    new_media = dcraw_image(media)

    try do
      get_size(new_media)
    after
      File.rm(new_media.path)
    end
  end

  def get_size(%__MODULE__{path: path, type: type}) when guard_is_image(type) do
    cmdline = ["identify", "-format", "%wx%h:", path]
    [cmd | args] = cmdline
    {text, 0} = System.cmd(cmd, args, stderr_to_stdout: false)
    [size_text | _] = String.split(text, ":")
    [width, height] = String.split(size_text, "x", max_parts: 2)
    {width, ""} = Integer.parse(width)
    {height, ""} = Integer.parse(height)
    %Size{width: width, height: height}
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
  def resize(
        %__MODULE__{type: type, subtype: subtype} = media,
        new_path,
        %SizeRequirement{} = requirement
      )
      when guard_is_raw(type, subtype) do
    new_media = dcraw_image(media)

    try do
      resize(new_media, new_path, requirement)
    after
      File.rm(new_media.path)
    end
  end

  def resize(%__MODULE__{path: path} = media, new_path, %SizeRequirement{} = requirement) do
    new_size = get_new_size(media, requirement)

    [type, subtype] = String.split(requirement.format, "/")

    result =
      try do
        case {type, subtype, is_video(media)} do
          {"image", "gif", true} ->
            Thumbnex.animated_gif_thumbnail(path, new_path,
              width: new_size.width,
              height: new_size.height
            )

          {"video", _, _} ->
            resize_video(media, new_path, requirement)

          {"image", _, _} ->
            extension =
              requirement.format
              |> MIME.extensions()
              |> hd()

            case Thumbnex.create_thumbnail(path, new_path,
                   format: extension,
                   width: new_size.width,
                   height: new_size.height
                 ) do
              :ok -> :ok
              {:error, reason} -> {:error, "thumbnail creation failed: #{reason}"}
            end
        end
      rescue
        e ->
          File.rm(new_path)
          reraise e, __STACKTRACE__
      end

    case result do
      :ok -> get_media(new_path, requirement.format)
      {:error, _reason} -> result
    end
  end

  @spec get_crf(format :: String.t()) :: String.t()
  def get_crf("video/webm"), do: "30"
  def get_crf("video/mp4"), do: "30"
  def get_crf("video/ogg"), do: "60"

  @spec get_resize_video_commands(
          media :: t(),
          new_path :: String.t(),
          new_size :: Size.t(),
          new_format :: String.t(),
          temp_dir :: String.t()
        ) :: list(list(String.t()))
  defp get_resize_video_commands(
         %__MODULE__{path: path},
         new_path,
         %Size{} = new_size,
         "video/webm",
         temp_dir
       ) do
    temp_file = Path.join(temp_dir, "ffmpeg2pass")

    pass1 = [
      "ffmpeg",
      "-y",
      "-i",
      path,
      "-q:v",
      "4",
      "-c:v",
      "libvpx-vp9",
      "-b:v",
      "0",
      "-crf",
      "30",
      # "-max_muxing_queue_size",
      # "1024",
      "-filter:v",
      "scale=#{new_size.width}:#{new_size.height}",
      "-pass",
      "1",
      "-passlogfile",
      temp_file,
      "-f",
      "null",
      "/dev/null"
    ]

    pass2 = [
      "ffmpeg",
      "-y",
      "-i",
      path,
      "-q:v",
      "4",
      "-c:v",
      "libvpx-vp9",
      "-b:v",
      "0",
      "-crf",
      "30",
      # "-max_muxing_queue_size",
      # "1024",
      "-filter:v",
      "scale=#{new_size.width}:#{new_size.height}",
      "-pass",
      "2",
      "-passlogfile",
      temp_file,
      "-c:a",
      "libopus",
      "-f",
      "webm",
      new_path
    ]

    [pass1, pass2]
  end

  defp get_resize_video_commands(
         %__MODULE__{path: path},
         new_path,
         %Size{} = new_size,
         new_format,
         _
       ) do
    cmd_common = [
      "ffmpeg",
      "-y",
      "-i",
      path,
      "-q:v",
      "4",
      "-b:v",
      "0",
      "-crf",
      "30",
      # "-max_muxing_queue_size",
      # "1024",
      "-filter:v",
      "scale=#{new_size.width}:#{new_size.height}"
    ]

    cmd_format =
      case new_format do
        "video/ogg" ->
          ["-f", "ogg", "-codec:a", "libvorbis"]

        "video/mp4" ->
          ["-f", "mp4", "-strict", "experimental"]

        "video/webm" ->
          ["-f", "webm"]
      end

    [cmd_common ++ cmd_format ++ [new_path]]
  end

  @spec run_commands(commands :: list(list(String.t()))) :: :ok | {:error, String.t()}
  defp run_commands([]), do: :ok

  defp run_commands([head | tail]) do
    [cmd | args] = head

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_, 0} ->
        run_commands(tail)

      {text, rc} ->
        IO.puts(inspect(head))
        IO.puts(text)
        {:error, "#{cmd} returned #{rc}"}
    end
  end

  @spec resize_video(t(), String.t(), SizeRequirement.t()) :: :ok | {:error, String.t()}
  def resize_video(%__MODULE__{type: type} = media, new_path, requirement)
      when guard_is_video(type) do
    temp_dir = Temp.mkdir!()

    try do
      new_format = requirement.format
      new_size = get_new_size(media, requirement)
      commands = get_resize_video_commands(media, new_path, new_size, new_format, temp_dir)

      case run_commands(commands) do
        :ok -> :ok
        {:error, _} = error -> error
      end
    rescue
      e ->
        File.rm(new_path)
        reraise e, __STACKTRACE__
    after
      File.rm_rf(temp_dir)
    end
  end

  @spec rotate(t(), String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def rotate(%__MODULE__{type: type}, _new_path, _rotate_amount) when guard_is_video(type),
    do: {:error, "rotation not supported for video"}

  def rotate(%__MODULE__{type: type, subtype: "jpeg"} = media, new_path, rotate_amount)
      when guard_is_image(type) do
    arg =
      case rotate_amount do
        "auto" -> "-a"
        "90" -> "-9"
        "180" -> "-1"
        "270" -> "-2"
      end

    commands = [
      ["exiftran", "-o", new_path, "-i", media.path, arg]
    ]

    try do
      case run_commands(commands) do
        :ok ->
          get_media(new_path, get_format(media))

        {:error, _} = error ->
          error
      end
    rescue
      e ->
        File.rm(new_path)
        reraise e, __STACKTRACE__
    end
  end

  @spec get_exif(t()) :: map()
  def get_exif(%__MODULE__{} = media) do
    Tools.exif(media.path)
  end

  @spec get_datetime(t()) :: NaiveDateTime.t()
  def get_datetime(%__MODULE__{} = media) do
    exif = get_exif(media)

    invalid_times = [
      nil,
      "    :  :     :  :  ",
      "0000:00:00 00:00:00"
    ]

    datetime =
      [
        "EXIF:DateTimeOriginal",
        "QuickTime:CreateDate",
        "QuickTime:ModifyDate",
        "EXIF:DateTimeDigitized",
        "EXIF:CreateDate"
      ]
      |> Enum.map(fn name -> Map.get(exif, name, nil) end)
      |> Enum.reject(fn value -> Enum.member?(invalid_times, value) end)
      |> Enum.map(&parse_exif_datetime/1)
      |> List.first()

    case datetime do
      nil ->
        {:ok, datetime} =
          File.stat!(media.path).mtime
          |> NaiveDateTime.from_erl()

        datetime

      datetime ->
        datetime
    end
  end

  @spec get_sha256_hash(t()) :: binary()
  def get_sha256_hash(%__MODULE__{} = media) do
    File.stream!(media.path, 2_048)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
  end

  @spec get_num_bytes(t()) :: integer()
  def get_num_bytes(%__MODULE__{} = media) do
    %{size: size} = File.stat!(media.path)
    size
  end

  @spec compute_file_metadata(t()) ::
          {:ok, %{sha256_hash: binary(), num_bytes: integer()}} | {:error, String.t()}
  def compute_file_metadata(media) do
    try do
      %{size: num_bytes} = File.stat!(media.path)

      sha256_hash =
        File.stream!(media.path, 2_048)
        |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
        |> :crypto.hash_final()

      {:ok, %{sha256_hash: sha256_hash, num_bytes: num_bytes}}
    rescue
      e in File.Error -> {:error, "failed to compute file metadata: #{e.reason}"}
    end
  end

  @spec delete(t()) :: :ok | {:error, String.t()}
  def delete(%__MODULE__{} = media) do
    case File.rm(media.path) do
      :ok -> :ok
      {:error, reason} -> {:error, "rm #{media.path} failed: #{inspect(reason)}"}
    end
  end

  @spec copy(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def copy(%__MODULE__{} = media, dest_path) do
    dest_directory = Path.dirname(dest_path)

    with :ok <- File.mkdir_p(dest_directory),
         {:ok, _} <- File.copy(media.path, dest_path),
         :ok <- File.chmod(dest_path, 0o644) do
      get_media(dest_path, get_format(media))
    else
      {:error, reason} ->
        {:error, "copy #{media.path} to #{dest_path} failed: #{inspect(reason)}"}
    end
  end
end
