class AddDraftResourceToWhatsappConversations < ActiveRecord::Migration[6.1]
  def up
    add_column :whatsapp_conversations, :draft_resource_type, :string
    add_column :whatsapp_conversations, :draft_resource_id, :bigint
    add_index :whatsapp_conversations, [:draft_resource_type, :draft_resource_id],
      name: "index_whatsapp_conversations_on_draft_resource"

    execute(<<~SQL)
      UPDATE whatsapp_conversations
      SET draft_resource_type = 'Proposal', draft_resource_id = proposal_id
      WHERE proposal_id IS NOT NULL
    SQL

    remove_column :whatsapp_conversations, :proposal_id
  end

  def down
    add_column :whatsapp_conversations, :proposal_id, :integer
    add_index :whatsapp_conversations, :proposal_id

    execute(<<~SQL)
      UPDATE whatsapp_conversations
      SET proposal_id = draft_resource_id
      WHERE draft_resource_type = 'Proposal'
    SQL

    remove_index :whatsapp_conversations, name: "index_whatsapp_conversations_on_draft_resource"
    remove_column :whatsapp_conversations, :draft_resource_type
    remove_column :whatsapp_conversations, :draft_resource_id
  end
end
