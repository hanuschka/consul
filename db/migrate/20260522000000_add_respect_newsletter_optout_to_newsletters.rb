class AddRespectNewsletterOptoutToNewsletters < ActiveRecord::Migration[6.1]
  def change
    add_column :newsletters, :respect_newsletter_optout, :boolean, default: true, null: false
  end
end
