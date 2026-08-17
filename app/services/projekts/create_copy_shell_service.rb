class Projekts::CreateCopyShellService < ApplicationService
  def initialize(source:, user:)
    @source = source
    @user = user
  end

  # The copy is created empty and inactive before the job starts, so the admin
  # gets a row to watch immediately and the copy status has a record of
  # its own to live on.
  def call
    Projekt.create!(
      name: I18n.t("adm.projekts.projekts.copy.copy_name", name: source.name),
      author: user,
      parent_id: source.parent_id,
      activated: false,
      copied_from_projekt_id: source.id,
      copy_status: "processing"
    )
  end

  private

    attr_reader :source, :user
end
