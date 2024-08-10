module AdminActions::Memos
  extend ActiveSupport::Concern

  included do
    respond_to :js

    before_action :set_memoable, only: [:create]
    before_action :set_memo, only: [:destroy]
  end

  def create
    @memo = @memoable.memos.new(memo_params.merge(user: current_user))
    authorize! :add_memo, @memo.root_memoable

    @memo.save!

    render "admin/memos/create"
  end

  private

    def memo_params
      params.require(:memo).permit(:text, :memoable_id, :memoable_type, :parent_id)
    end

    def set_memoable
      @memoable ||= memo_params[:memoable_type].constantize.find(memo_params[:memoable_id])
    end

    def set_memo
      @memo = Memo.find(params[:id])
    end
end
