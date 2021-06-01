defmodule PenguinMemories.Loaders do
  alias PenguinMemories.Database
  alias PenguinMemories.Database.Query
  alias PenguinMemories.Urls

  defmodule ListRequest do
    @moduledoc """
    List of icons to display
    """
    @type t :: %__MODULE__{
            type: Database.object_type(),
            filter: Query.Filter.t(),
            before_name: String.t(),
            before_key: String.t(),
            after_name: String.t(),
            after_key: String.t(),
            show_selected_name: String.t(),
            show_selected_value: boolean()
          }
    @enforce_keys [
      :type,
      :filter,
      :before_name,
      :before_key,
      :after_name,
      :after_key,
      :show_selected_name,
      :show_selected_value
    ]
    defstruct type: nil,
              filter: %Query.Filter{},
              before_name: nil,
              before_key: nil,
              after_name: nil,
              after_key: nil,
              show_selected_name: nil,
              show_selected_value: false
  end

  defmodule ListResponse do
    @moduledoc """
    List of icons to display
    """
    @type t :: %__MODULE__{
            before_key: String.t(),
            before_url: String.t(),
            after_key: String.t(),
            after_url: String.t(),
            icons: list(Query.Icon.t()),
            count: integer()
          }
    @enforce_keys [:before_key, :before_url, :after_key, :after_url, :icons, :count]
    defstruct before_key: nil,
              before_url: nil,
              after_key: nil,
              after_url: nil,
              icons: [],
              count: 0
  end

  @spec create_before_after_url(
          uri :: URI.t(),
          this_name :: String.t(),
          other_name :: String.t(),
          key :: String.t() | nil
        ) :: String.t() | nil
  def create_before_after_url(_uri, _this_name, _other_name, nil), do: nil

  def create_before_after_url(%URI{} = url, this_name, other_name, key) do
    url
    |> Urls.url_merge(%{this_name => key}, [other_name])
    |> URI.to_string()
  end

  @spec load_objects(request :: ListRequest.t(), url :: URI.t()) :: ListResponse.t()
  def load_objects(%ListRequest{} = request, %URI{} = url) do
    {icons, before_key, after_key, count} =
      Query.get_page_icons(
        request.filter,
        request.before_key,
        request.after_key,
        20,
        "thumb",
        request.type
      )

    before_url = create_before_after_url(url, request.before_name, request.after_name, before_key)
    after_url = create_before_after_url(url, request.after_name, request.before_name, after_key)

    %ListResponse{
      before_key: before_key,
      before_url: before_url,
      after_key: after_key,
      after_url: after_url,
      icons: icons,
      count: count
    }
  end
end
