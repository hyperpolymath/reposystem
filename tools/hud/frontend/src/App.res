// SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

/**
 * Gitvisor Main Application
 *
 * TEA-based dashboard for Git platform management.
 */

module Model = {
  type platform = GitHub | GitLab

  type tab =
    | Dashboard
    | Repositories
    | Issues
    | PullRequests
    | Settings

  type repository = {
    id: string,
    name: string,
    owner: string,
    platform: platform,
    description: option<string>,
    stars: int,
    isPrivate: bool,
  }

  type issue = {
    id: string,
    number: int,
    title: string,
    state: string,
    repository: string,
    platform: platform,
  }

  type pullRequest = {
    id: string,
    number: int,
    title: string,
    state: string,
    repository: string,
    platform: platform,
  }

  type dashboardWidget =
    | RepoList
    | IssueList
    | PRList
    | ActivityFeed
    | SEOWidget
    | Custom(string)

  type t = {
    currentTab: tab,
    repositories: array<repository>,
    issues: array<issue>,
    pullRequests: array<pullRequest>,
    widgets: array<dashboardWidget>,
    loading: bool,
    error: option<string>,
    connectedPlatforms: array<platform>,
    searchQuery: string,
    seoReport: option<SEOWidget.seoReport>,
    seoTrend: option<SEOWidget.seoTrend>,
  }

  let initial: t = {
    currentTab: Dashboard,
    repositories: [],
    issues: [],
    pullRequests: [],
    widgets: [RepoList, IssueList, PRList, SEOWidget],
    loading: false,
    error: None,
    connectedPlatforms: [],
    searchQuery: "",
    seoReport: None,
    seoTrend: None,
  }
}

module Msg = {
  type t =
    // Navigation
    | SwitchTab(Model.tab)
    // Data loading
    | LoadRepositories
    | RepositoriesLoaded(result<array<Model.repository>, string>)
    | LoadIssues
    | IssuesLoaded(result<array<Model.issue>, string>)
    | LoadPullRequests
    | PullRequestsLoaded(result<array<Model.pullRequest>, string>)
    // Search
    | UpdateSearch(string)
    | Search
    // Platform connection
    | ConnectPlatform(Model.platform)
    | DisconnectPlatform(Model.platform)
    | PlatformConnected(result<Model.platform, string>)
    // Dashboard customization
    | AddWidget(Model.dashboardWidget)
    | RemoveWidget(Model.dashboardWidget)
    | ReorderWidgets(array<Model.dashboardWidget>)
    // UI
    | DismissError
    // SEO
    | LoadSEOReport(string)
    | SEOReportLoaded(result<SEOWidget.seoReport, string>)
    | LoadSEOTrend(string)
    | SEOTrendLoaded(result<SEOWidget.seoTrend, string>)
    | AnalyzeRepository(string)
}

let init = (): (Model.t, Tea.Cmd.t<Msg.t>) => {
  (Model.initial, Tea.Cmd.none)
}

let update = (msg: Msg.t, model: Model.t): (Model.t, Tea.Cmd.t<Msg.t>) => {
  switch msg {
  | Msg.SwitchTab(tab) => ({...model, currentTab: tab}, Tea.Cmd.none)

  | Msg.LoadRepositories => ({...model, loading: true}, Tea.Cmd.none)

  | Msg.RepositoriesLoaded(result) =>
    switch result {
    | Ok(repos) => ({...model, repositories: repos, loading: false}, Tea.Cmd.none)
    | Error(err) => ({...model, error: Some(err), loading: false}, Tea.Cmd.none)
    }

  | Msg.LoadIssues => ({...model, loading: true}, Tea.Cmd.none)

  | Msg.IssuesLoaded(result) =>
    switch result {
    | Ok(issues) => ({...model, issues, loading: false}, Tea.Cmd.none)
    | Error(err) => ({...model, error: Some(err), loading: false}, Tea.Cmd.none)
    }

  | Msg.LoadPullRequests => ({...model, loading: true}, Tea.Cmd.none)

  | Msg.PullRequestsLoaded(result) =>
    switch result {
    | Ok(prs) => ({...model, pullRequests: prs, loading: false}, Tea.Cmd.none)
    | Error(err) => ({...model, error: Some(err), loading: false}, Tea.Cmd.none)
    }

  | Msg.UpdateSearch(query) => ({...model, searchQuery: query}, Tea.Cmd.none)

  | Msg.Search => (model, Tea.Cmd.none) // TODO: Implement search command

  | Msg.ConnectPlatform(_platform) => ({...model, loading: true}, Tea.Cmd.none)

  | Msg.DisconnectPlatform(platform) => (
      {
        ...model,
        connectedPlatforms: model.connectedPlatforms->Array.filter(p => p != platform),
      },
      Tea.Cmd.none,
    )

  | Msg.PlatformConnected(result) =>
    switch result {
    | Ok(platform) => (
        {
          ...model,
          connectedPlatforms: model.connectedPlatforms->Array.concat([platform]),
          loading: false,
        },
        Tea.Cmd.none,
      )
    | Error(err) => ({...model, error: Some(err), loading: false}, Tea.Cmd.none)
    }

  | Msg.AddWidget(widget) => (
      {...model, widgets: model.widgets->Array.concat([widget])},
      Tea.Cmd.none,
    )

  | Msg.RemoveWidget(widget) => (
      {...model, widgets: model.widgets->Array.filter(w => w != widget)},
      Tea.Cmd.none,
    )

  | Msg.ReorderWidgets(widgets) => ({...model, widgets}, Tea.Cmd.none)

  | Msg.DismissError => ({...model, error: None}, Tea.Cmd.none)

  | Msg.LoadSEOReport(_url) => ({...model, loading: true}, Tea.Cmd.none)

  | Msg.SEOReportLoaded(result) =>
    switch result {
    | Ok(report) => ({...model, seoReport: Some(report), loading: false}, Tea.Cmd.none)
    | Error(err) => ({...model, error: Some(err), loading: false}, Tea.Cmd.none)
    }

  | Msg.LoadSEOTrend(_url) => (model, Tea.Cmd.none)

  | Msg.SEOTrendLoaded(result) =>
    switch result {
    | Ok(trend) => ({...model, seoTrend: Some(trend)}, Tea.Cmd.none)
    | Error(_) => (model, Tea.Cmd.none) // Silently ignore trend errors
    }

  | Msg.AnalyzeRepository(_url) => ({...model, loading: true}, Tea.Cmd.none)
  }
}

let subscriptions = (_model: Model.t): Tea.Sub.t<Msg.t> => {
  Tea.Sub.none
}

module View = {
  @react.component
  let make = (~model: Model.t, ~dispatch: Msg.t => unit) => {
    let tabName = tab =>
      switch tab {
      | Model.Dashboard => "Dashboard"
      | Model.Repositories => "Repositories"
      | Model.Issues => "Issues"
      | Model.PullRequests => "Pull Requests"
      | Model.Settings => "Settings"
      }

    let tabs = [
      Model.Dashboard,
      Model.Repositories,
      Model.Issues,
      Model.PullRequests,
      Model.Settings,
    ]

    <div className="gitvisor">
      <header className="gitvisor-header">
        <h1> {React.string("Gitvisor")} </h1>
        <nav className="gitvisor-tabs">
          {tabs
          ->Array.map(tab =>
            <button
              key={tabName(tab)}
              className={model.currentTab == tab ? "active" : ""}
              onClick={_ => dispatch(Msg.SwitchTab(tab))}>
              {React.string(tabName(tab))}
            </button>
          )
          ->React.array}
        </nav>
      </header>
      <main className="gitvisor-main">
        {switch model.error {
        | Some(err) =>
          <div className="error-banner">
            {React.string(err)}
            <button onClick={_ => dispatch(Msg.DismissError)}>
              {React.string("Dismiss")}
            </button>
          </div>
        | None => React.null
        }}
        {model.loading ? <div className="loading"> {React.string("Loading...")} </div> : React.null}
        {switch model.currentTab {
        | Model.Dashboard => <DashboardView model dispatch />
        | Model.Repositories => <RepositoriesView model dispatch />
        | Model.Issues => <IssuesView model dispatch />
        | Model.PullRequests => <PullRequestsView model dispatch />
        | Model.Settings => <SettingsView model dispatch />
        }}
      </main>
    </div>
  }
}

and DashboardView = {
  @react.component
  let make = (~model: Model.t, ~dispatch: Msg.t => unit) => {
    <div className="dashboard">
      <h2> {React.string("Dashboard")} </h2>
      <div className="widgets">
        {model.widgets
        ->Array.mapWithIndex((widget, i) =>
          <div key={Int.toString(i)} className="widget">
            {switch widget {
            | Model.RepoList => <div> {React.string("Repository List Widget")} </div>
            | Model.IssueList => <div> {React.string("Issue List Widget")} </div>
            | Model.PRList => <div> {React.string("PR List Widget")} </div>
            | Model.ActivityFeed => <div> {React.string("Activity Feed Widget")} </div>
            | Model.SEOWidget =>
              <SEOWidget
                report={model.seoReport}
                trend={model.seoTrend}
                onAnalyze={url => dispatch(Msg.AnalyzeRepository(url))}
              />
            | Model.Custom(name) => <div> {React.string(`Custom: ${name}`)} </div>
            }}
          </div>
        )
        ->React.array}
      </div>
    </div>
  }
}

and RepositoriesView = {
  @react.component
  let make = (~model: Model.t, ~dispatch as _: Msg.t => unit) => {
    <div className="repositories">
      <h2> {React.string("Repositories")} </h2>
      <ul>
        {model.repositories
        ->Array.map(repo =>
          <li key={repo.id}>
            <strong> {React.string(`${repo.owner}/${repo.name}`)} </strong>
            {switch repo.description {
            | Some(desc) => <p> {React.string(desc)} </p>
            | None => React.null
            }}
          </li>
        )
        ->React.array}
      </ul>
    </div>
  }
}

and IssuesView = {
  @react.component
  let make = (~model: Model.t, ~dispatch as _: Msg.t => unit) => {
    <div className="issues">
      <h2> {React.string("Issues")} </h2>
      <ul>
        {model.issues
        ->Array.map(issue =>
          <li key={issue.id}>
            <span className="issue-number"> {React.string(`#${Int.toString(issue.number)}`)} </span>
            {React.string(issue.title)}
          </li>
        )
        ->React.array}
      </ul>
    </div>
  }
}

and PullRequestsView = {
  @react.component
  let make = (~model: Model.t, ~dispatch as _: Msg.t => unit) => {
    <div className="pull-requests">
      <h2> {React.string("Pull Requests")} </h2>
      <ul>
        {model.pullRequests
        ->Array.map(pr =>
          <li key={pr.id}>
            <span className="pr-number"> {React.string(`#${Int.toString(pr.number)}`)} </span>
            {React.string(pr.title)}
          </li>
        )
        ->React.array}
      </ul>
    </div>
  }
}

and SettingsView = {
  @react.component
  let make = (~model: Model.t, ~dispatch: Msg.t => unit) => {
    <div className="settings">
      <h2> {React.string("Settings")} </h2>
      <section>
        <h3> {React.string("Connected Platforms")} </h3>
        <ul>
          {[Model.GitHub, Model.GitLab]
          ->Array.map(platform => {
            let name = switch platform {
            | Model.GitHub => "GitHub"
            | Model.GitLab => "GitLab"
            }
            let connected = model.connectedPlatforms->Array.includes(platform)
            <li key={name}>
              {React.string(name)}
              {connected
                ? <button onClick={_ => dispatch(Msg.DisconnectPlatform(platform))}>
                    {React.string("Disconnect")}
                  </button>
                : <button onClick={_ => dispatch(Msg.ConnectPlatform(platform))}>
                    {React.string("Connect")}
                  </button>}
            </li>
          })
          ->React.array}
        </ul>
      </section>
    </div>
  }
}

let app: Tea.app<Model.t, Msg.t> = {
  init,
  update,
  view: (model, dispatch) => <View model dispatch />,
  subscriptions,
}
