defmodule PenguinMemories.Urls do
  @moduledoc """
  URL helper functions
  """
  @spec url_merge(URI.t(), %{required(String.t()) => String.t()}, list(String.t())) :: URI.t()
  def url_merge(url, merge, delete) do
    query =
      case url.query do
        nil -> %{}
        query -> URI.decode_query(query)
      end

    query = Map.drop(query, delete)
    query = Map.merge(query, merge)
    query = URI.encode_query(query)
    %URI{url | query: query}
  end

  @spec set_path(URI.t(), path :: String.t()) :: URI.t()
  def set_path(%URI{} = url, path) do
    %{url | path: path}
  end

  @spec url_to_path(URI.t()) :: URI.t()
  def url_to_path(%URI{} = url) do
    %{url | authority: nil, host: nil, scheme: nil}
  end

  @spec parse_url(String.t()) :: URI.t()
  def parse_url(url) do
    url |> URI.parse() |> url_to_path()
  end
end
