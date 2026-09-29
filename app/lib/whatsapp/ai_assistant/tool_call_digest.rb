module Whatsapp::AiAssistant::ToolCallDigest
  # What a tool was called with and what it answered, cut down to the shape of the
  # call for one DecisionLog line. The tool's name was all that survived a turn once
  # its history had scrolled out of the replayed window, so a reply a tester
  # reported could only be rebuilt from the message bodies: which page was asked
  # for, which phase was started, what the counts said.
  #
  # Structure only: numbers, booleans and single-token strings — ids, action ids,
  # scopes — go in as they are, and any other text as its length. Tool arguments
  # carry the citizen's own words, a draft, a comment, a typed answer, and a log
  # file is not covered by the retention period the assistant tells them their
  # chat is kept for.
  TOKEN = /\A[\w\-.:]{1,64}\z/

  ARGUMENT_PREFIX = "arg".freeze
  RESULT_PREFIX = "res".freeze

  module_function

  def arguments(args)
    flattened(args, prefix: ARGUMENT_PREFIX, shaper: method(:shape_of))
  end

  # A halt is flagged rather than shown: its text is a summary written for the
  # model, and nothing promises it holds no citizen words. The error's wording is
  # dropped for the same reason — that there was one is what the line is for.
  def result(tool_result)
    if tool_result.is_a?(::ToolHalt)
      return { "#{RESULT_PREFIX}.halted" => true }
    end

    if !tool_result.is_a?(Hash)
      return { RESULT_PREFIX => shape_of(tool_result) }
    end

    error = tool_result[:error].presence || tool_result["error"].presence
    digest = flattened(
      tool_result.except(:error, "error"), prefix: RESULT_PREFIX, shaper: method(:result_shape_of)
    )

    return digest if error.blank?

    digest.merge("#{RESULT_PREFIX}.error" => true)
  end

  def flattened(hash, prefix:, shaper:)
    return {} if !hash.is_a?(Hash)

    hash.to_h { |key, value| ["#{prefix}.#{key}", shaper.call(value)] }.compact
  end

  # A result's lists are its rows, and how many came back is what a reply's numbers
  # are checked against; their ids would fill the line before the counts beside them.
  def result_shape_of(value)
    return "[#{value.size}]" if value.is_a?(Array)

    shape_of(value)
  end

  def shape_of(value)
    case value
    when nil, true, false, Numeric then value
    when Symbol then value.to_s
    when String then text_shape(value)
    when Array then list_shape(value)
    when Hash then hash_shape(value)
    else text_shape(value.to_s)
    end
  end

  def text_shape(text)
    return text if text.match?(TOKEN)

    "text(#{text.length})"
  end

  # The rows and buttons of a send are named by their action ids, which say what
  # was offered without a word of what the model wrote on them.
  def list_shape(items)
    action_ids =
      items
        .select { |item| item.is_a?(Hash) }
        .map { |item| (item[:action_id] || item["action_id"]).to_s }
        .select { |identifier| identifier.match?(TOKEN) }

    return "[#{items.size}]" if action_ids.empty?

    action_ids.join(",")
  end

  # One level in, scalars only — enough for counts, which is the hash a reply's
  # numbers come from.
  def hash_shape(hash)
    pairs =
      hash
        .transform_values { |value| shape_of(value) }
        .select { |_key, inner| scalar?(inner) }
        .map { |key, inner| "#{key}:#{inner}" }

    return "{#{hash.size} keys}" if pairs.empty?

    pairs.join(",")
  end

  def scalar?(value)
    value.is_a?(Numeric) || [true, false].include?(value)
  end
end
