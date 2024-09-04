class Admin::VotationTypes::FieldsComponent < ApplicationComponent
  include TranslatableFormHelper
  include GlobalizeHelper

  def initialize(question)
    @question = question
    @votation_type = @question.votation_type
  end

  def hide_hint_class(votation_type_name)
    return "" if votation_type_name == @votation_type.vote_type
    return "" if (votation_type_name == "unique" && @votation_type.vote_type.nil?)

    "hide"
  end

  def hide_max_votes_input_class(votation_type_name)
    "hide" if !VotationType.allowing_multiple_answers.include?(votation_type_name)
  end

  def hide_max_votes_per_answer_input_class(votation_type_name)
    "hide" if "multiple_with_weight" != votation_type_name
  end

  def hide_rating_scale_labels_class(votation_type_name)
    "hide" if votation_type_name != "rating_scale"
  end
end
