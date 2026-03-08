# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule Gitvisor.Platforms.Adapter do
  @moduledoc """
  Behaviour for Git platform adapters.

  Defines the contract that GitHub, GitLab, and future platform
  adapters must implement to provide a unified interface.
  """

  @type platform :: :github | :gitlab | :gitea | :codeberg
  @type token :: String.t()
  @type repo_path :: {owner :: String.t(), name :: String.t()}
  @type result(t) :: {:ok, t} | {:error, term()}

  # Repository operations
  @callback get_repository(token, repo_path) :: result(map())
  @callback list_repositories(token, opts :: keyword()) :: result([map()])
  @callback search_repositories(token, query :: String.t(), opts :: keyword()) :: result([map()])

  # Issue operations
  @callback list_issues(token, repo_path, opts :: keyword()) :: result([map()])
  @callback get_issue(token, repo_path, number :: integer()) :: result(map())
  @callback create_issue(token, repo_path, params :: map()) :: result(map())
  @callback update_issue(token, repo_path, number :: integer(), params :: map()) :: result(map())

  # Pull/Merge Request operations
  @callback list_pull_requests(token, repo_path, opts :: keyword()) :: result([map()])
  @callback get_pull_request(token, repo_path, number :: integer()) :: result(map())
  @callback create_pull_request(token, repo_path, params :: map()) :: result(map())
  @callback merge_pull_request(token, repo_path, number :: integer(), opts :: keyword()) :: result(map())

  # User operations
  @callback get_current_user(token) :: result(map())
  @callback get_user(token, username :: String.t()) :: result(map())

  # Webhook operations
  @callback parse_webhook(payload :: map(), headers :: map()) :: result(map())

  @doc """
  Normalizes platform-specific data to Gitvisor's internal format.
  """
  @callback normalize(type :: atom(), data :: map()) :: map()

  @optional_callbacks [parse_webhook: 2]
end
