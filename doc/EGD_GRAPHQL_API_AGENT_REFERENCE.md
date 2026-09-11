# European Go Database GraphQL API — agent reference

> Self-contained development reference derived from the EGD Developer Guide and the complete published GraphQL API reference for version `2026.02`, retrieved 2026-09-11. Use this file when the live documentation is unavailable.

## Agent instructions

- Target **API version `2026.02`**. Do not silently substitute fields or operations from older EGD APIs.
- Endpoint: `https://europeangodatabase.eu/api/v2026.02/graphql`
- Send GraphQL requests as HTTP `POST` with a JSON body and a bearer token.
- Every request requires authentication.
- The published schema documents **queries only**. It does not document any mutations, despite generic text saying a `read-write` token permits mutations. Do not invent mutations; consult newer documentation if writes are required.
- GraphQL fields must be selected explicitly. A relation such as `games`, `players`, or `placements` is not returned unless requested with a sub-selection.
- List relations embedded in objects return `{ data, total }` and are not page-based. Top-level plural queries return pagination metadata and require `pagination`.
- Dates are exposed as `String`, not a date scalar. The documentation does not formally specify their format; observed examples and filter naming imply date strings, so validate actual responses before relying on formatting.
- Nullable fields lack `!`. Handle them as `null`.
- Never log, commit, embed, or expose an API token.

## Sources and scope

- Developer guide: <https://europeangodatabase.eu/docs/devs/guide>
- GraphQL reference: <https://europeangodatabase.eu/docs/api/graphql/2026.02/>
- Token-management page: <https://europeangodatabase.eu/EGD/EGD_2_0/developer.php>
- Login: <https://europeangodatabase.eu/login>

This summary includes every documented query, object, input, enum, and practically relevant directive in the published `2026.02` reference.

## Authentication

EGD uses personal access tokens. A logged-in user creates them under **Developer → New Token** in the EGD admin panel.

Token form:

| Field | Meaning |
|---|---|
| Name | Human-readable label, maximum 255 characters |
| Scope | `read` for queries; `read-write` for queries and mutations |
| Expiry | Optional: 30, 60, or 90 days, or no expiry |

The plain-text token is displayed once. Copy and store it securely at creation time.

Use these headers:

```http
Authorization: Bearer <your-token>
Content-Type: application/json
```

Recommended environment variable:

```bash
export EGD_API_TOKEN='...'
```

Example request:

```bash
curl -X POST 'https://europeangodatabase.eu/api/v2026.02/graphql' \
  -H "Authorization: Bearer $EGD_API_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary @- <<'JSON'
{
  "query": "query FindPlayers($term: String!, $pagination: PaginationInput!) { playersSearch(search: $term, pagination: $pagination) { data { pin firstName lastName rating } total currentPage lastPage hasMorePages } }",
  "variables": { "term": "Ilya", "pagination": { "page": 1, "limit": 5 } }
}
JSON
```

Use one token per integration, choose the least-privileged scope, set an expiry where practical, rotate tokens, and monitor **Last used**. Deleting a token revokes it immediately and subsequent use returns HTTP `401 Unauthorized`.

## Request and error handling

Canonical JSON request:

```json
{
  "query": "query OperationName($variable: Type!) { ... }",
  "variables": { "variable": "value" },
  "operationName": "OperationName"
}
```

GraphQL can return HTTP success while including application errors. Always inspect both `errors` and `data`:

```json
{
  "data": null,
  "errors": [{ "message": "..." }]
}
```

Treat `401` as missing, expired, deleted, or invalid authentication. The documentation does not specify rate limits, retry rules, error extensions, timeouts, or idempotency behavior. Implement bounded retries only for transient transport/5xx failures, never blind retries for unknown writes.

## Query root

```graphql
type Query {
  game(id: Int!): Game
  games(filter: GameFilterInput, order: GameOrderInput, pagination: PaginationInput!): GamePagination
  player(pin: Int!): Player
  playersSearch(search: String!, filter: PlayerFilterInput, order: PlayerOrderInput, pagination: PaginationInput!): PlayerPagination
  players(filter: PlayerFilterInput, order: PlayerOrderInput, pagination: PaginationInput!): PlayerPagination
  tournament(code: String!): Tournament
  tournaments(filter: TournamentFilterInput, order: TournamentOrderInput, pagination: PaginationInput!): TournamentPagination
}
```

Single-record queries return nullable objects when no matching record exists. Top-level list queries require `pagination`, even when filters and ordering are omitted.

### `game`

Find one game by unique integer ID.

```graphql
query GameById($id: Int!) {
  game(id: $id) {
    id tournamentCode date round
    pinPlayer1 color1 pinPlayer2 color2
    handicap result sgfCode
  }
}
```

### `games`

List and page through games with optional filtering and ordering.

```graphql
query GamesForPlayer($pin: Int!, $page: Int!) {
  games(
    filter: { pinPlayer: $pin }
    order: { field: date, direction: DESC }
    pagination: { page: $page, limit: 100 }
  ) {
    data { id date tournamentCode round result pinPlayer1 pinPlayer2 }
    total from to perPage currentPage lastPage hasMorePages
  }
}
```

### `player`

Find one player by unique PIN.

```graphql
query PlayerByPin($pin: Int!) {
  player(pin: $pin) {
    pin firstName lastName countryCode club grade rating
    biography { type biography photo }
  }
}
```

### `playersSearch`

Typo-tolerant free-text search across last name, first name, country, club, and PIN. It also accepts structured player filters and ordering.

```graphql
query SearchPlayers($term: String!) {
  playersSearch(
    search: $term
    order: { field: rating, direction: DESC }
    pagination: { page: 1, limit: 20 }
  ) {
    data { pin firstName lastName countryCode club grade rating }
    total hasMorePages
  }
}
```

### `players`

Structured player listing without the required typo-tolerant search term.

```graphql
query DutchDanPlayers {
  players(
    filter: { countryCode: "NL", grade: "1d" }
    order: { field: lastName, direction: ASC }
    pagination: { page: 1, limit: 100 }
  ) {
    data { pin firstName lastName club grade rating }
    total currentPage lastPage
  }
}
```

### `tournament`

Find one tournament by unique string code.

```graphql
query TournamentByCode($code: String!) {
  tournament(code: $code) {
    code description date city nation tournamentClass rounds totalPlayers status
    placements { total data { placement pinPlayer firstName lastName gradeDeclared } }
  }
}
```

### `tournaments`

List and page through tournaments with optional filtering and ordering.

```graphql
query TournamentsInRange($from: String!, $to: String!) {
  tournaments(
    filter: { dateFrom: $from, dateTo: $to, nation: "NL" }
    order: { field: date, direction: DESC }
    pagination: { page: 1, limit: 100 }
  ) {
    data { code description date city nation tournamentClass rounds totalPlayers status }
    total hasMorePages
  }
}
```

## Complete object schema

```graphql
type Biography {
  type: String!
  biography: String
  photo: String
}

type Game {
  id: Int!
  tournamentCode: String!
  date: String
  round: Int!
  pinPlayer1: Int!
  color1: GameColorEnum
  pinPlayer2: Int!
  color2: GameColorEnum
  handicap: Int!
  result: String!
  sgfCode: String
  tournament: Tournament
  player1: Player
  player2: Player
}

type Placement {
  id: Int!
  pinPlayer: Int!
  tournamentCode: String!
  lastName: String
  firstName: String
  countryCode: String!
  club: String
  placement: Int!
  gradeDeclared: String!
  wonGames: Int!
  lostGames: Int!
  jigoGames: Int!
  precedentRating: Float
  followingRating: Float
  player: Player
  tournament: Tournament
}

type Player {
  pin: Int!
  agaId: Int!
  lastName: String!
  firstName: String!
  countryCode: String!
  club: String
  grade: String!
  egfPlacement: Int
  rating: Int
  deltaRating: Int
  proposedGrade: String!
  totalTournaments: Int
  lastAppearance: String
  gamesAsPlayer1(filter: GameFilterInput, order: GameOrderInput): GameList
  gamesAsPlayer2(filter: GameFilterInput, order: GameOrderInput): GameList
  placements: PlacementList
  tournaments(filter: TournamentFilterInput, order: TournamentOrderInput): TournamentList
  biography: Biography
}

type Tournament {
  code: String!
  reliability: Int
  description: String
  categoriesDescription: String
  date: String!
  city: String!
  nation: String!
  tournamentClass: TournamentClassEnum!
  rounds: Int!
  totalPlayers: Int
  status: TournamentStatusEnum!
  games(filter: GameFilterInput, order: GameOrderInput): GameList
  placements: PlacementList
  players(filter: PlayerFilterInput, order: PlayerOrderInput): PlayerList
}
```

### Field semantics and encoded values

| Type.field | Meaning |
|---|---|
| `Biography.type` | Biography content type; allowed values are not documented |
| `Biography.photo` | Photo identifier or URL |
| `Game.color1`, `color2` | `Black` or `White`; field descriptions also mention stored codes `b`/`w` |
| `Game.handicap` | Handicap stones |
| `Game.result` | Documented stored results: `=` jigo, `1` player 1 won, `2` player 2 won, `w` white won, `b` black won |
| `Game.sgfCode` | SGF game-record code, if available |
| `Placement.*Name`, `countryCode`, `club` | Values recorded at the time of the tournament |
| `Placement.gradeDeclared` | Grade declared at registration |
| `Placement.precedentRating` | Rating before the tournament |
| `Placement.followingRating` | Rating after the tournament |
| `Player.agaId` | American Go Association ID; schema marks it non-null |
| `Player.grade` | Current grade, e.g. `1d` or `5k` |
| `Player.rating` | Current GoR (Go Rating) |
| `Player.deltaRating` | Rating change |
| `Player.proposedGrade` | Grade proposed by rating calculations |
| `Tournament.reliability` | Reliability score of tournament data; range not documented |
| `Tournament.categoriesDescription` | Human-readable category description |
| `Tournament.nation`, `Player.countryCode` | Two-letter country code |

## Container types

Embedded relation lists:

```graphql
type GameList      { data: [Game!]!,       total: Int! }
type PlacementList { data: [Placement!]!,  total: Int! }
type PlayerList    { data: [Player!]!,     total: Int! }
type TournamentList { data: [Tournament!]!, total: Int! }
```

Top-level pagination wrappers:

```graphql
type GamePagination {
  data: [Game!]!
  total: Int!
  from: Int
  to: Int
  perPage: Int!
  currentPage: Int!
  lastPage: Int!
  hasMorePages: Boolean!
}

type PlayerPagination {
  data: [Player!]!
  total: Int!
  from: Int
  to: Int
  perPage: Int!
  currentPage: Int!
  lastPage: Int!
  hasMorePages: Boolean!
}

type TournamentPagination {
  data: [Tournament!]!
  total: Int!
  from: Int
  to: Int
  perPage: Int!
  currentPage: Int!
  lastPage: Int!
  hasMorePages: Boolean!
}
```

`from` and `to` are nullable item positions. `perPage` is the number of items per page, `currentPage` and `lastPage` are page numbers, and `hasMorePages` indicates whether another page follows.

## Complete input schema

```graphql
input PaginationInput {
  page: Int       # default 1
  limit: Int      # default 30, maximum 100
}

input GameFilterInput {
  tournamentCode: String
  round: Int
  result: String
  pinPlayer1: Int
  pinPlayer2: Int
  pinPlayer: Int  # either player has this PIN
  dateFrom: String
  dateTo: String
}

input GameOrderInput {
  field: GameOrderFieldEnum
  direction: OrderDirectionEnum
}

input PlayerFilterInput {
  pin: Int
  countryCode: String
  grade: String
  club: String
  lastName: String    # SQL LIKE search
  firstName: String   # SQL LIKE search
  ratingFrom: Int     # rating >= value
  ratingTo: Int       # rating <= value
}

input PlayerOrderInput {
  field: PlayerOrderFieldEnum
  direction: OrderDirectionEnum
}

input TournamentFilterInput {
  code: String
  nation: String
  tournamentClass: TournamentClassEnum
  categoryType: String
  status: TournamentStatusEnum
  rounds: Int
  description: String # SQL LIKE search
  city: String        # SQL LIKE search
  dateFrom: String
  dateTo: String
}

input TournamentOrderInput {
  field: TournamentOrderFieldEnum
  direction: OrderDirectionEnum
}
```

The documentation does not define wildcard escaping or case sensitivity for SQL `LIKE` filters. Do not assume client-supplied `%`/`_` behavior without testing.

## Complete enums

```graphql
enum GameColorEnum { Black White }

enum GameOrderFieldEnum {
  date
  round
  handicap
  result
  tournamentCode
}

enum PlayerOrderFieldEnum {
  pin
  lastName
  firstName
  countryCode
  rating
  totalTournaments
}

enum TournamentOrderFieldEnum {
  code
  date
  city
  nation
  tournamentClass
  rounds
  totalPlayers
  status
}

enum OrderDirectionEnum { ASC DESC }
enum TournamentClassEnum { A B C D }
enum TournamentStatusEnum { Rejected Approved AwaitingValidation Validated }
```

Enum spelling and case are exact. Do not quote enum literals inside a GraphQL document; do represent them as strings when passing them through JSON variables.

## Relationship map

- `Game.tournament → Tournament`
- `Game.player1 → Player`
- `Game.player2 → Player`
- `Placement.player → Player`
- `Placement.tournament → Tournament`
- `Player.gamesAsPlayer1 → GameList`
- `Player.gamesAsPlayer2 → GameList`
- `Player.placements → PlacementList`
- `Player.tournaments → TournamentList`
- `Player.biography → Biography`
- `Tournament.games → GameList`
- `Tournament.placements → PlacementList`
- `Tournament.players → PlayerList`

Nested relations can create large/cyclic query graphs. Request only fields needed by the caller and avoid recursively expanding both directions.

## Pagination recipe

Top-level plural operations use page-number pagination:

1. Start with `{ page: 1, limit: 100 }` (or a smaller limit).
2. Consume `data`.
3. If `hasMorePages` is true, increment `page` and repeat.
4. Stop when `hasMorePages` is false; do not infer completion only from `data.length`.
5. If data may change during traversal, results can drift because the API documents no snapshot or cursor consistency guarantee.

Pseudo-code:

```text
page = 1
do:
  result = query(pagination: {page, limit: 100})
  consume(result.data)
  page += 1
while result.hasMorePages
```

## Directives and scalars

Standard GraphQL directives are available:

```graphql
directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT
directive @deprecated(reason: String = "No longer supported")
  on FIELD_DEFINITION | ARGUMENT_DEFINITION | INPUT_FIELD_DEFINITION | ENUM_VALUE
directive @oneOf on INPUT_OBJECT
directive @specifiedBy(url: String!) on SCALAR
```

Scalars are standard GraphQL `Boolean`, `Float`, `Int`, and `String`. `Int` is signed 32-bit (`-2^31` through `2^31-1`); `Float` is IEEE-754 double precision; strings are UTF-8 text.

## Implementation checklist for an agent

1. Read `EGD_API_TOKEN` from secure configuration.
2. POST to the exact versioned endpoint with bearer and JSON headers.
3. Prefer named operations and variables over interpolating values into query text.
4. Always supply `pagination` to `games`, `players`, `playersSearch`, and `tournaments`.
5. Keep `limit <= 100`.
6. Use `playersSearch` for fuzzy text lookup; use `players` for structured filters.
7. Preserve enum casing exactly.
8. Treat all nullable schema fields as potentially `null`.
9. Check HTTP status, JSON decoding, and GraphQL `errors` separately.
10. Select minimal fields and avoid deeply recursive relationships.
11. Do not assume undocumented date formats, rate limits, LIKE semantics, or mutations.
12. Record the API version in the client and review upstream docs before upgrading.

## Known documentation gaps

The published reference does not specify:

- mutations or mutation input types;
- rate limits or request-cost limits;
- date-string format and timezone semantics;
- wildcard/case rules for SQL `LIKE` filters;
- stable ordering when `order` is omitted or sort keys tie;
- default sort field/direction;
- maximum nesting/query complexity;
- error codes/extensions beyond the documented token-related HTTP `401`;
- whether schema introspection is enabled;
- whether list relations have an undocumented size cap;
- the meaning/range of tournament reliability or biography type;
- SGF retrieval semantics for `sgfCode`.

When behavior depends on one of these points, probe safely against the API or obtain updated official documentation rather than guessing.
