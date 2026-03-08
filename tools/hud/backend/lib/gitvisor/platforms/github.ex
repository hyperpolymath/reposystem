# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Platforms.GitHub do
  @moduledoc """
  GitHub platform adapter.

  Implements the Adapter behaviour for GitHub's GraphQL and REST APIs.
  Prefers GraphQL for most operations but falls back to REST when needed.
  """

  use GenServer

  @behaviour Gitvisor.Platforms.Adapter

  @graphql_endpoint "https://api.github.com/graphql"
  @rest_endpoint "https://api.github.com"

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Adapter implementation

  @impl Gitvisor.Platforms.Adapter
  def get_repository(token, {owner, name}) do
    query = """
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        id
        name
        nameWithOwner
        description
        url
        isPrivate
        isFork
        stargazerCount
        forkCount
        primaryLanguage { name color }
        defaultBranchRef { name }
        owner { login avatarUrl }
        createdAt
        updatedAt
      }
    }
    """

    graphql(token, query, %{owner: owner, name: name})
    |> handle_response(:repository)
  end

  @impl Gitvisor.Platforms.Adapter
  def list_repositories(token, opts \\ []) do
    limit = Keyword.get(opts, :first, 20)

    query = """
    query($first: Int!) {
      viewer {
        repositories(first: $first, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            id
            name
            nameWithOwner
            description
            url
            isPrivate
            stargazerCount
          }
        }
      }
    }
    """

    graphql(token, query, %{first: limit})
    |> handle_response(:viewer, :repositories)
  end

  @impl Gitvisor.Platforms.Adapter
  def search_repositories(token, query_string, opts \\ []) do
    limit = Keyword.get(opts, :first, 20)

    query = """
    query($query: String!, $first: Int!) {
      search(query: $query, type: REPOSITORY, first: $first) {
        nodes {
          ... on Repository {
            id
            name
            nameWithOwner
            description
            url
            isPrivate
            stargazerCount
          }
        }
      }
    }
    """

    graphql(token, query, %{query: query_string, first: limit})
    |> handle_response(:search)
  end

  @impl Gitvisor.Platforms.Adapter
  def list_issues(token, {owner, name}, opts \\ []) do
    limit = Keyword.get(opts, :first, 20)
    states = Keyword.get(opts, :states, ["OPEN"])

    query = """
    query($owner: String!, $name: String!, $first: Int!, $states: [IssueState!]) {
      repository(owner: $owner, name: $name) {
        issues(first: $first, states: $states, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            id
            number
            title
            body
            state
            author { login avatarUrl }
            labels(first: 10) { nodes { name color } }
            createdAt
            updatedAt
          }
        }
      }
    }
    """

    graphql(token, query, %{owner: owner, name: name, first: limit, states: states})
    |> handle_response(:repository, :issues)
  end

  @impl Gitvisor.Platforms.Adapter
  def get_issue(token, {owner, name}, number) do
    query = """
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        issue(number: $number) {
          id
          number
          title
          body
          state
          author { login avatarUrl }
          labels(first: 10) { nodes { name color } }
          comments(first: 50) { nodes { body author { login } createdAt } }
          createdAt
          updatedAt
        }
      }
    }
    """

    graphql(token, query, %{owner: owner, name: name, number: number})
    |> handle_response(:repository, :issue)
  end

  @impl Gitvisor.Platforms.Adapter
  def create_issue(token, {owner, name}, params) do
    # Use REST API for mutations (simpler)
    rest(token, :post, "/repos/#{owner}/#{name}/issues", params)
  end

  @impl Gitvisor.Platforms.Adapter
  def update_issue(token, {owner, name}, number, params) do
    rest(token, :patch, "/repos/#{owner}/#{name}/issues/#{number}", params)
  end

  @impl Gitvisor.Platforms.Adapter
  def list_pull_requests(token, {owner, name}, opts \\ []) do
    limit = Keyword.get(opts, :first, 20)
    states = Keyword.get(opts, :states, ["OPEN"])

    query = """
    query($owner: String!, $name: String!, $first: Int!, $states: [PullRequestState!]) {
      repository(owner: $owner, name: $name) {
        pullRequests(first: $first, states: $states, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes {
            id
            number
            title
            body
            state
            author { login avatarUrl }
            headRefName
            baseRefName
            mergeable
            createdAt
            updatedAt
          }
        }
      }
    }
    """

    graphql(token, query, %{owner: owner, name: name, first: limit, states: states})
    |> handle_response(:repository, :pullRequests)
  end

  @impl Gitvisor.Platforms.Adapter
  def get_pull_request(token, {owner, name}, number) do
    query = """
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          id
          number
          title
          body
          state
          author { login avatarUrl }
          headRefName
          baseRefName
          mergeable
          additions
          deletions
          changedFiles
          reviews(first: 20) { nodes { state author { login } body } }
          comments(first: 50) { nodes { body author { login } createdAt } }
          createdAt
          updatedAt
        }
      }
    }
    """

    graphql(token, query, %{owner: owner, name: name, number: number})
    |> handle_response(:repository, :pullRequest)
  end

  @impl Gitvisor.Platforms.Adapter
  def create_pull_request(token, {owner, name}, params) do
    rest(token, :post, "/repos/#{owner}/#{name}/pulls", params)
  end

  @impl Gitvisor.Platforms.Adapter
  def merge_pull_request(token, {owner, name}, number, opts \\ []) do
    params = %{
      merge_method: Keyword.get(opts, :method, "merge")
    }

    rest(token, :put, "/repos/#{owner}/#{name}/pulls/#{number}/merge", params)
  end

  @impl Gitvisor.Platforms.Adapter
  def get_current_user(token) do
    query = """
    query {
      viewer {
        id
        login
        name
        email
        avatarUrl
        bio
        company
        location
        websiteUrl
        createdAt
      }
    }
    """

    graphql(token, query, %{})
    |> handle_response(:viewer)
  end

  @impl Gitvisor.Platforms.Adapter
  def get_user(token, username) do
    query = """
    query($login: String!) {
      user(login: $login) {
        id
        login
        name
        email
        avatarUrl
        bio
        company
        location
        websiteUrl
        createdAt
      }
    }
    """

    graphql(token, query, %{login: username})
    |> handle_response(:user)
  end

  @impl Gitvisor.Platforms.Adapter
  def normalize(type, data), do: Gitvisor.Platforms.GitHub.Normalizer.normalize(type, data)

  # Private helpers

  defp graphql(token, query, variables) do
    Req.post(@graphql_endpoint,
      json: %{query: query, variables: variables},
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Accept", "application/vnd.github.v4+json"}
      ]
    )
  end

  defp rest(token, method, path, body \\ nil) do
    opts = [
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Accept", "application/vnd.github.v3+json"}
      ]
    ]

    opts = if body, do: Keyword.put(opts, :json, body), else: opts

    apply(Req, method, [@rest_endpoint <> path, opts])
  end

  defp handle_response({:ok, %{status: 200, body: %{"data" => data}}}, key) do
    {:ok, data[Atom.to_string(key)]}
  end

  defp handle_response({:ok, %{status: 200, body: %{"data" => data}}}, key1, key2) do
    {:ok, get_in(data, [Atom.to_string(key1), Atom.to_string(key2)])}
  end

  defp handle_response({:ok, %{body: %{"errors" => errors}}}, _) do
    {:error, errors}
  end

  defp handle_response({:error, reason}, _), do: {:error, reason}
  defp handle_response({:error, reason}, _, _), do: {:error, reason}

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
