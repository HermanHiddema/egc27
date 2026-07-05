class RebuildSearchDocuments < ActiveRecord::Migration[8.1]
  def up
    say_with_time("Rebuilding pg_search documents for searchable models") do
      %w[Page Article Sponsor].each do |model_name|
        PgSearch::Multisearch.rebuild(model_name.constantize)
      end
    end
  end

  def down
    execute("DELETE FROM pg_search_documents WHERE searchable_type IN ('Page', 'Article', 'Sponsor')")
  end
end
