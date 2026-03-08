# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule GitvisorWeb.Schema.Types.Common do
  @moduledoc """
  Common GraphQL types used across the schema.
  """

  use Absinthe.Schema.Notation

  @desc "Supported Git platforms"
  enum :platform_type do
    value :github, description: "GitHub"
    value :gitlab, description: "GitLab"
    value :gitea, description: "Gitea (future)"
    value :codeberg, description: "Codeberg (future)"
  end

  @desc "Pagination cursor"
  scalar :cursor do
    parse fn input ->
      case input do
        %Absinthe.Blueprint.Input.String{value: value} -> {:ok, value}
        _ -> :error
      end
    end

    serialize fn value -> value end
  end

  @desc "Pagination info"
  object :page_info do
    field :has_next_page, non_null(:boolean)
    field :has_previous_page, non_null(:boolean)
    field :start_cursor, :cursor
    field :end_cursor, :cursor
  end

  @desc "Generic connection for pagination"
  object :connection do
    field :edges, list_of(:edge)
    field :page_info, non_null(:page_info)
    field :total_count, :integer
  end

  @desc "Generic edge for pagination"
  object :edge do
    field :cursor, non_null(:cursor)
    field :node, :node
  end

  @desc "Node interface"
  interface :node do
    field :id, non_null(:id)

    resolve_type fn
      %{__struct__: Gitvisor.Repository}, _ -> :repository
      %{__struct__: Gitvisor.Issue}, _ -> :issue
      %{__struct__: Gitvisor.PullRequest}, _ -> :pull_request
      %{__struct__: Gitvisor.User}, _ -> :user
      _, _ -> nil
    end
  end

  @desc "Timestamps"
  object :timestamps do
    field :created_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end

  @desc "Label for issues/PRs"
  object :label do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :color, non_null(:string)
    field :description, :string
  end
end
