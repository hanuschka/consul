# Turns one serialized node back into an unsaved record. Both a local copy and
# a cross-instance import read nodes of the same shape, so this is the only
# place that knows how to make a record out of one.
class Projekts::Copying::AttributeReader
  class UnexpectedModelError < StandardError; end

  # Every model a projekt bundle can contain, as base classes -- phases and
  # their resources are STI, so subclasses are accepted too. A node naming
  # anything else is refused rather than constantized: an imported bundle
  # arrives from another instance and is not trusted input.
  PERMITTED_BASE_MODELS = [
    Projekt,
    ProjektPhase,
    ProjektSetting,
    ProjektPhaseSetting,
    SiteCustomization::Page,
    SiteCustomization::ContentBlock,
    SiteCustomization::EmailTemplate,
    MapLocation,
    MapLayer,
    Milestone,
    ProgressBar,
    NavbarItem,
    UserResourceCriteria,
    ProjektPointOfInterestCategory,
    Image,
    Document,
    AdminImage,
    Poll,
    Poll::Question,
    Poll::Question::Answer,
    Poll::Question::Answer::Video,
    VotationType,
    Budget,
    Budget::Group,
    Budget::Heading,
    Budget::Phase,
    Formular,
    FormularField,
    FormularFollowUpLetter,
    *Projekts::Copying::PhaseResourceCopier::PLAIN_RESOURCE_MODELS
  ].freeze

  CLASS_NAME = /\A[A-Z][A-Za-z0-9]*(?:::[A-Z][A-Za-z0-9]*)*\z/

  # An export strips every foreign key, so a record that requires an author
  # arrives without one. The admin the copy belongs to is the closest thing the
  # target has. A local copy carries the source's author and is left alone.
  def initialize(author:)
    @author = author
  end

  def source_id(node)
    node["source_id"]
  end

  def model(node)
    name = node["model"].to_s
    raise UnexpectedModelError, "malformed model name" if !name.match?(CLASS_NAME)

    model = name.safe_constantize

    if !model.is_a?(Class) || PERMITTED_BASE_MODELS.none? { |base| model <= base }
      raise UnexpectedModelError, "#{name} may not be copied"
    end

    model
  end

  def attributes(node, except: [])
    model = model(node)
    attributes = (node["attributes"] || {}).except(*except.map(&:to_s))
    return attributes if !model.column_names.include?("author_id")
    return attributes if attributes["author_id"].present?

    attributes.merge("author_id" => author&.id)
  end

  def translations(node, except: [])
    excluded = except.map(&:to_s)

    (node["translations"] || {}).transform_values { |values| values.except(*excluded) }
  end

  private

    attr_reader :author
end
