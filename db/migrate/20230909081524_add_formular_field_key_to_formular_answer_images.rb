class AddFormularFieldKeyToFormularAnswerImages < ActiveRecord::Migration[5.2]
  def change
    add_column :formular_answer_images, :formular_field_key, :string
  end
end
