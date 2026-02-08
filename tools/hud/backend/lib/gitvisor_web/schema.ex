# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

defmodule GitvisorWeb.Schema do
  @moduledoc """
  The main GraphQL schema for Gitvisor.

  Provides unified access to Git platforms (GitHub, GitLab) through
  a consistent interface with support for:
  - Repository operations
  - Issue and PR management
  - User/organization data
  - Dashboard customization
  - Real-time subscriptions
  """

  use Absinthe.Schema

  import_types Absinthe.Type.Custom
  import_types GitvisorWeb.Schema.Types.Common
  import_types GitvisorWeb.Schema.Types.Repository
  import_types GitvisorWeb.Schema.Types.Issue
  import_types GitvisorWeb.Schema.Types.PullRequest
  import_types GitvisorWeb.Schema.Types.User
  import_types GitvisorWeb.Schema.Types.Dashboard
  import_types GitvisorWeb.Schema.Types.Platform
  import_types GitvisorWeb.Schema.Types.SEO

  query do
    @desc "Get the current authenticated user"
    field :viewer, :user do
      resolve &GitvisorWeb.Resolvers.User.viewer/3
    end

    @desc "Get a repository by platform and path"
    field :repository, :repository do
      arg :platform, non_null(:platform_type)
      arg :owner, non_null(:string)
      arg :name, non_null(:string)
      resolve &GitvisorWeb.Resolvers.Repository.get/3
    end

    @desc "Search repositories across platforms"
    field :search_repositories, list_of(:repository) do
      arg :query, non_null(:string)
      arg :platforms, list_of(:platform_type)
      arg :first, :integer, default_value: 20
      resolve &GitvisorWeb.Resolvers.Repository.search/3
    end

    @desc "Get user's dashboard configuration"
    field :dashboard, :dashboard do
      resolve &GitvisorWeb.Resolvers.Dashboard.get/3
    end

    @desc "List connected platforms for current user"
    field :platforms, list_of(:platform_connection) do
      resolve &GitvisorWeb.Resolvers.Platform.list/3
    end

    @desc "Get SEO report for a repository"
    field :seo_report, :seo_report do
      arg :repository_url, non_null(:string)
      arg :force_refresh, :boolean, default_value: false
      resolve &GitvisorWeb.Resolvers.SEO.get_seo_report/3
    end

    @desc "Get SEO trend for a repository"
    field :seo_trend, :seo_trend do
      arg :repository_url, non_null(:string)
      resolve &GitvisorWeb.Resolvers.SEO.get_seo_trend/3
    end
  end

  mutation do
    @desc "Connect a new platform (GitHub/GitLab)"
    field :connect_platform, :platform_connection do
      arg :platform, non_null(:platform_type)
      arg :access_token, non_null(:string)
      resolve &GitvisorWeb.Resolvers.Platform.connect/3
    end

    @desc "Disconnect a platform"
    field :disconnect_platform, :boolean do
      arg :platform, non_null(:platform_type)
      resolve &GitvisorWeb.Resolvers.Platform.disconnect/3
    end

    @desc "Create or update dashboard configuration"
    field :save_dashboard, :dashboard do
      arg :input, non_null(:dashboard_input)
      resolve &GitvisorWeb.Resolvers.Dashboard.save/3
    end

    @desc "Create a custom widget"
    field :create_widget, :widget do
      arg :input, non_null(:widget_input)
      resolve &GitvisorWeb.Resolvers.Dashboard.create_widget/3
    end

    @desc "Create an issue on a platform"
    field :create_issue, :issue do
      arg :input, non_null(:issue_input)
      resolve &GitvisorWeb.Resolvers.Issue.create/3
    end

    @desc "Create a pull/merge request"
    field :create_pull_request, :pull_request do
      arg :input, non_null(:pull_request_input)
      resolve &GitvisorWeb.Resolvers.PullRequest.create/3
    end

    @desc "Trigger SEO analysis for a repository"
    field :analyze_repository, :seo_report do
      arg :repository_url, non_null(:string)
      resolve &GitvisorWeb.Resolvers.SEO.analyze_repository/3
    end
  end

  subscription do
    @desc "Subscribe to repository events"
    field :repository_events, :repository_event do
      arg :repository_id, non_null(:id)

      config fn args, _res ->
        {:ok, topic: "repo:#{args.repository_id}"}
      end
    end

    @desc "Subscribe to dashboard updates"
    field :dashboard_updates, :dashboard do
      config fn _args, %{context: context} ->
        {:ok, topic: "dashboard:#{context.current_user.id}"}
      end
    end
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(Gitvisor.Platforms, Gitvisor.Platforms.data())
      |> Dataloader.add_source(Gitvisor.Dashboard, Gitvisor.Dashboard.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
