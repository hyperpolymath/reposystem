# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Platforms.GitLab do
  @moduledoc """
  GitLab platform adapter.

  Implements the Adapter behaviour for GitLab's GraphQL and REST APIs.
  Supports both GitLab.com and self-hosted instances.
  """

  use GenServer

  @behaviour Gitvisor.Platforms.Adapter

  @default_endpoint "https://gitlab.com/api"

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Adapter implementation

  @impl Gitvisor.Platforms.Adapter
  def get_repository(token, {owner, name}) do
    # GitLab uses project path as identifier
    project_path = "#{owner}/#{name}"
    encoded_path = URI.encode_www_form(project_path)

    rest(token, :get, "/v4/projects/#{encoded_path}")
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def list_repositories(token, opts \\ []) do
    params = %{
      per_page: Keyword.get(opts, :first, 20),
      order_by: "updated_at",
      owned: true
    }

    rest(token, :get, "/v4/projects", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def search_repositories(token, query_string, opts \\ []) do
    params = %{
      search: query_string,
      per_page: Keyword.get(opts, :first, 20)
    }

    rest(token, :get, "/v4/projects", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def list_issues(token, {owner, name}, opts \\ []) do
    project_path = URI.encode_www_form("#{owner}/#{name}")
    state = Keyword.get(opts, :state, "opened")

    params = %{
      per_page: Keyword.get(opts, :first, 20),
      state: state
    }

    rest(token, :get, "/v4/projects/#{project_path}/issues", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def get_issue(token, {owner, name}, number) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    rest(token, :get, "/v4/projects/#{project_path}/issues/#{number}")
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def create_issue(token, {owner, name}, params) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    rest(token, :post, "/v4/projects/#{project_path}/issues", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def update_issue(token, {owner, name}, number, params) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    rest(token, :put, "/v4/projects/#{project_path}/issues/#{number}", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def list_pull_requests(token, {owner, name}, opts \\ []) do
    project_path = URI.encode_www_form("#{owner}/#{name}")
    state = Keyword.get(opts, :state, "opened")

    params = %{
      per_page: Keyword.get(opts, :first, 20),
      state: state
    }

    # GitLab calls them "merge requests"
    rest(token, :get, "/v4/projects/#{project_path}/merge_requests", params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def get_pull_request(token, {owner, name}, number) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    rest(token, :get, "/v4/projects/#{project_path}/merge_requests/#{number}")
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def create_pull_request(token, {owner, name}, params) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    # Map to GitLab's field names
    gitlab_params = %{
      source_branch: params[:head],
      target_branch: params[:base],
      title: params[:title],
      description: params[:body]
    }

    rest(token, :post, "/v4/projects/#{project_path}/merge_requests", gitlab_params)
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def merge_pull_request(token, {owner, name}, number, _opts \\ []) do
    project_path = URI.encode_www_form("#{owner}/#{name}")

    rest(token, :put, "/v4/projects/#{project_path}/merge_requests/#{number}/merge")
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def get_current_user(token) do
    rest(token, :get, "/v4/user")
    |> handle_response()
  end

  @impl Gitvisor.Platforms.Adapter
  def get_user(token, username) do
    rest(token, :get, "/v4/users", %{username: username})
    |> handle_response()
    |> case do
      {:ok, [user | _]} -> {:ok, user}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  @impl Gitvisor.Platforms.Adapter
  def normalize(type, data), do: Gitvisor.Platforms.GitLab.Normalizer.normalize(type, data)

  # Private helpers

  defp rest(token, method, path, params \\ nil, endpoint \\ @default_endpoint) do
    url = endpoint <> path
    opts = [
      headers: [
        {"PRIVATE-TOKEN", token},
        {"Accept", "application/json"}
      ]
    ]

    opts =
      cond do
        params && method in [:get, :head] ->
          Keyword.put(opts, :params, params)

        params ->
          Keyword.put(opts, :json, params)

        true ->
          opts
      end

    apply(Req, method, [url, opts])
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404}}) do
    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
