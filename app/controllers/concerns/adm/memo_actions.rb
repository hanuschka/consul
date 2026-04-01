module Adm::MemoActions
  extend ActiveSupport::Concern

  ALLOWED_MEMOABLE_TYPES = %w[DeficiencyReport Idea Budget::Investment Memo].freeze

  def create
    @memoable = find_memoable
    @memo = @memoable.memos.new(memo_params.merge(user: current_user))
    authorize [:adm, @memo], policy_class: Adm::MemoPolicy

    @memo.save!

    render "adm/memos/create"
  end

  def send_notification
    @memo = Memo.find(params[:id])
    authorize [:adm, @memo], policy_class: Adm::MemoPolicy

    NotificationServices::MemoNotifier.call(@memo.id)
    @memo.reload

    render "adm/memos/send_notification"
  end

  private

    def memo_params
      params.require(:memo).permit(:text, :memoable_id, :memoable_type, :parent_id)
    end

    def find_memoable
      type = memo_params[:memoable_type]
      raise ActiveRecord::RecordNotFound unless type.in?(ALLOWED_MEMOABLE_TYPES)

      type.constantize.find(memo_params[:memoable_id])
    end
end
