class RebuildSearchDocuments < ActiveRecord::Migration[8.1]
  def up
    say_with_time("Rebuilding pg_search documents for searchable models") do
      [Page, Article, Sponsor].each do |model|
        PgSearch::Multisearch.rebuild(model)
      end
    end
  end

  def down
    execute("DELETE FROM pg_search_documents WHERE searchable_type IN ('Page', 'Article', 'Sponsor')")
  end
end
