defmodule PenguinMemoriesWeb.ObjectListLive do
  use PenguinMemoriesWeb, :live_view

  alias PenguinMemories.Objects

  @impl true
  def mount(params, _session, socket) do
    assigns = [
      type: params["type"],
      active: params["type"],
      icons: [],
      requested_before_key: nil,
      requested_after_key: nil,
      before_url: nil,
      after_url: nil,
      total_count: 0,
      search_spec: %{},
    ]

    {:ok, assign(socket, assigns)}
  end

  @spec uri_merge(URI.t(), %{required(String.t()) => String.t()}, list(String.t())) :: URI.t()
  defp uri_merge(uri, merge, delete) do
    query = case uri.query do
              nil -> %{}
              query -> URI.decode_query(query)
            end
    query = Map.merge(query, merge)
    query = Map.drop(query, delete)
    query = URI.encode_query(query)
    %URI{uri | query: query}
  end

  @impl true
  def handle_params(params, uri, socket) do
    requested_before_key = params["before"]
    requested_after_key = params["after"]
    type_name = params["type"]

    parsed_uri = URI.parse(uri)

    parent_id = cond do
      (id = params["id"]) != nil -> id
      (id = params["parent_id"]) != nil -> id
      true -> nil
    end

    params = case parent_id do
               nil -> params
               _ -> Map.put(params, "parent_id", parent_id)
             end

    type = Objects.get_for_type(type_name)
    {icons, before_key, after_key, total_count} = type.get_icons(params, requested_before_key, requested_after_key)

    before_url = case before_key do
                   nil -> nil
                   key ->
                     parsed_uri
                     |> uri_merge(%{"before"=>key}, ["after"])
                     |> URI.to_string()
                 end

    after_url = case after_key do
                  nil -> nil
                  key ->
                    parsed_uri
                    |> uri_merge(%{"after"=>key}, ["before"])
                    |> URI.to_string()
                end

    assigns = [
      type: type,
      type_name: type_name,
      active: type_name,
      icons: icons,
      requested_before_key: requested_before_key,
      requested_after_key: requested_after_key,
      before_url: before_url,
      after_url: after_url,
      total_count: total_count,
      search_spec: nil,
    ]

    {:noreply, assign(socket, assigns)}
  end
end
