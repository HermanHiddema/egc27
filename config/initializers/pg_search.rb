# Configure pg_search multisearch to use PostgreSQL full-text search with
# prefix matching so partial words (e.g. "trav" -> "travel") still match.
PgSearch.multisearch_options = {
  using: {
    tsearch: { prefix: true }
  }
}
