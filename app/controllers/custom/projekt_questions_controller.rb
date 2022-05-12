class ProjektQuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_question

  skip_authorization_check

  # load_and_authorize_resource :projekt
  # load_and_authorize_resource :question, through: :projekt

  has_orders %w[most_voted newest oldest], only: :show

  layout false

  def show
    @commentable = @question
    @comment_tree = CommentTree.new(@commentable, params[:page], @current_order)
    set_comment_flags(@comment_tree.comments)
    @answer = @question.answer_for_user(current_user) || ProjektQuestionAnswer.new
  end

  private

  def set_question
    @projekt = Projekt.find(params[:projekt_id])
    @question = @projekt.questions.find(params[:id])
  end
end
