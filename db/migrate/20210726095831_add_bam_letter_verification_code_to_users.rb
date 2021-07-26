class AddBamLetterVerificationCodeToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :bam_letter_verification_code, :integer
  end
end
