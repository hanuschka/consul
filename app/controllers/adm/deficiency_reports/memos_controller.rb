class Adm::DeficiencyReports::MemosController < Adm::DeficiencyReports::BaseController
  include Adm::MemoActions

  def create
    super

    memoable = @memo.root_memoable
    notify_watchers_about_change(memoable) if memoable.is_a?(DeficiencyReport)
  end
end
