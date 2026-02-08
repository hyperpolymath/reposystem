// SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

/**
 * GraphQL API client for Gitvisor backend
 */

let endpoint = "/api/graphql"

type graphqlResponse<'data> = {data: 'data, errors: option<array<{.."message": string}>>}

let query = async (query: string, variables: Js.Dict.t<Js.Json.t>): result<Js.Json.t, string> => {
  try {
    let response = await Fetch.fetch(
      endpoint,
      {
        method: #POST,
        headers: Fetch.Headers.fromObject({
          "Content-Type": "application/json",
        }),
        body: Fetch.Body.json(
          Js.Json.object_(
            Js.Dict.fromArray([("query", Js.Json.string(query)), ("variables", Js.Json.object_(variables))]),
          ),
        ),
      },
    )

    let json = await Fetch.Response.json(response)

    // Check for GraphQL errors
    switch Js.Json.decodeObject(json) {
    | Some(obj) =>
      switch Js.Dict.get(obj, "errors") {
      | Some(errors) =>
        switch Js.Json.decodeArray(errors) {
        | Some(errs) if Array.length(errs) > 0 =>
          Error("GraphQL error") // TODO: Extract message
        | _ =>
          switch Js.Dict.get(obj, "data") {
          | Some(data) => Ok(data)
          | None => Error("No data in response")
          }
        }
      | None =>
        switch Js.Dict.get(obj, "data") {
        | Some(data) => Ok(data)
        | None => Error("No data in response")
        }
      }
    | None => Error("Invalid response format")
    }
  } catch {
  | Js.Exn.Error(e) =>
    Error(
      switch Js.Exn.message(e) {
      | Some(msg) => msg
      | None => "Unknown error"
      },
    )
  }
}

module Queries = {
  let viewer = `
    query {
      viewer {
        id
        login
        name
        avatarUrl
      }
    }
  `

  let repositories = `
    query($first: Int!) {
      searchRepositories(query: "", first: $first) {
        id
        name
        owner
        description
        stars
        isPrivate
      }
    }
  `

  let issues = `
    query($repoOwner: String!, $repoName: String!, $platform: PlatformType!) {
      repository(platform: $platform, owner: $repoOwner, name: $repoName) {
        issues {
          id
          number
          title
          state
        }
      }
    }
  `

  let pullRequests = `
    query($repoOwner: String!, $repoName: String!, $platform: PlatformType!) {
      repository(platform: $platform, owner: $repoOwner, name: $repoName) {
        pullRequests {
          id
          number
          title
          state
        }
      }
    }
  `

  let seoReport = `
    query($repositoryUrl: String!, $forceRefresh: Boolean) {
      seoReport(repositoryUrl: $repositoryUrl, forceRefresh: $forceRefresh) {
        repositoryUrl
        overallScore
        status
        grade
        categories {
          name
          score
          maxScore
          percentage
          grade
        }
        priorityRecommendations
        totalRecommendations
        analyzedAt
      }
    }
  `

  let seoTrend = `
    query($repositoryUrl: String!) {
      seoTrend(repositoryUrl: $repositoryUrl) {
        currentScore
        previousScore
        change
        trendSlope
        minScore
        maxScore
        averageScore
        dates
        scores
      }
    }
  `
}

module Mutations = {
  let connectPlatform = `
    mutation($platform: PlatformType!, $accessToken: String!) {
      connectPlatform(platform: $platform, accessToken: $accessToken) {
        platform
        connected
      }
    }
  `

  let createIssue = `
    mutation($input: IssueInput!) {
      createIssue(input: $input) {
        id
        number
        title
      }
    }
  `

  let createPullRequest = `
    mutation($input: PullRequestInput!) {
      createPullRequest(input: $input) {
        id
        number
        title
      }
    }
  `

  let analyzeRepository = `
    mutation($repositoryUrl: String!) {
      analyzeRepository(repositoryUrl: $repositoryUrl) {
        repositoryUrl
        overallScore
        status
        grade
      }
    }
  `
}
