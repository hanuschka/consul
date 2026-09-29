class AddLanguageToWhatsappMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :whatsapp_messages, :language, :string, if_not_exists: true
  end
end
