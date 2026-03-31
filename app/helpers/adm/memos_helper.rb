module Adm::MemosHelper
  def adm_memos_create_path(memoable)
    root_memoable = memoable.is_a?(Memo) ? memoable.root_memoable : memoable

    case root_memoable
    when DeficiencyReport
      adm_deficiency_reports_memos_path
    when Idea
      adm_ideas_memos_path
    when Budget::Investment
      adm_projekts_memos_path
    end
  end

  def adm_memo_send_notification_path(memo)
    case memo.root_memoable
    when DeficiencyReport
      send_notification_adm_deficiency_reports_memo_path(memo)
    when Idea
      send_notification_adm_ideas_memo_path(memo)
    when Budget::Investment
      send_notification_adm_projekts_memo_path(memo)
    end
  end
end
