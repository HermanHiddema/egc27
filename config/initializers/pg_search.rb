# Configure pg_search multisearch to use PostgreSQL full-text search with
# prefix matching so partial words (e.g. "trav" -> "travel") still match, and
# the English dictionary so terms are stemmed (e.g. "running" -> "run").
PgSearch.multisearch_options = {
  using: {
    tsearch: { prefix: true, dictionary: "english" }
  }
}
