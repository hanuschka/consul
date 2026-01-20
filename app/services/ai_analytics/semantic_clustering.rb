class AiAnalytics::SemanticClustering < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    resources = AiAnalytics::ClusteringCore.get_resources(projekt_phase)
    return [] if resources.empty?

    generate_clustering(resources)
  end

  private

    def generate_clustering(resources)
      resource_type = AiAnalytics::ClusteringCore.resource_type_name(resources)
      resources_text = AiAnalytics::ClusteringCore.prepare_resources_data(resources)

      prompt = <<~TEXT
        You are an AI specialized in semantic intent analysis, attitudinal classification, and qualitative clustering of citizen #{resource_type}.
        Your task is not to group #{resource_type} by subject matter (e.g. environment, mobility, housing).
        Instead, your goal is to identify how #{resource_type} are framed, what attitude they express, and what kind of contribution they represent.

        ## Core Objective
        Analyze a list of #{resource_type} and cluster them based on their semantic attitude, polarity, intent, and constructive quality, such as:
        positive vs. neutral vs. negative orientation
        constructive vs. non-constructive contributions
        solution-oriented vs. problem-only statements
        supportive vs. oppositional framing
        emotional vs. rational tone

        ## Instructions
        Perform a deep semantic analysis of all #{resource_type}.
        Focus exclusively on:
        underlying intent (what the author wants to achieve)
        attitude and stance (supportive, critical, frustrated, proactive, etc.)
        polarity (positive, neutral, negative)
        degree of constructiveness
        tone (emotional, neutral, aggressive, cooperative)
        Explicitly ignore the topic domain (environment, traffic, education, etc.).
        Based on semantic intent and polarity, create 5–7 high-level SEMANTIC CLUSTERS.
        Each cluster must represent a distinct type of contribution, not a subject area.

        For each cluster, define 2–4 SUBCLUSTERS that capture finer distinctions in:
        - polarity
        - constructiveness
        - tone
        - level of solution depth

        Assign each proposal to exactly one subcluster, based on its strongest semantic fit.
        ## Mandatory Polarity Requirement
        The cluster structure must clearly differentiate between:
        Positive contributions (supportive, appreciative, solution-driven)
        Neutral contributions (descriptive, informational, procedural)
        Negative contributions (critical, frustrated, rejecting)
        Polarity must be a structural property of the clusters, not an afterthought or label added later.

        ## Cluster Design Requirements
        All clusters and subclusters must be:
        human-readable and intuitive
        mutually exclusive (no overlap)
        collectively exhaustive (every proposal fits somewhere)
        justified by semantic intent and attitude, not keywords or surface phrasing
        Avoid cluster names such as:
        “Environment”
        “Infrastructure”
        “Youth”
        “Digitalization”
        Prefer cluster names such as:
        “Constructive Solution Proposals”
        “Supportive and Affirmative Feedback”
        “Problem Descriptions Without Proposed Solutions”
        “Emotionally Charged Criticism”
        “Strategic or System-Level Suggestions”

        ## Output Format
        CLUSTER 1 — Cluster Name (semantic explanation of intent, tone, and polarity)
          Subcluster 1.1 — Subcluster Name (semantic criteria)      - Proposal ID: Proposal text      - Proposal ID: Proposal text
          Subcluster 1.2 — Subcluster Name      - ...
        CLUSTER 2 — Cluster Name

        You are an AI specialized in semantic analysis, topic extraction, and hierarchical clustering.


        Write all clusters and subcluster names in #{AiAnalytics::ClusteringCore.target_language}.

        #{resource_type.capitalize}:
        #{resources_text}
      TEXT

        # Your goals:
        # Perform a semantic analysis of all #{resource_type}.

        # Identify underlying themes, intentions, target groups, and conceptual similarities.
        # Ignore superficial wording; focus on meaning.
        # Based on your semantic understanding, create 5–7 high-level TOPICS that best represent the conceptual structure of the data.
        # For each topic, create 2–4 SUBTOPICS that capture finer semantic distinctions.
        # Assign each item to exactly one subtopic (whichever has the strongest semantic fit).
        # Ignore subtopics which dosent have at least one assigned resource.
        # Ensure topics and subtopics are: meaningful and human-friendly, non-overlapping , comprehensive (cover everything),
        # semantically justified (not based on superficial keywords).
        # Dont include resource name in topics and subtopics.
      response = Ai::RubyLlmFactory.chat_with_json_output(AiAnalytics::ClusteringCore.output_schema).ask(prompt)

      response.content["topics"]
    rescue StandardError => e
      Rails.logger.error("SemanticClustering error: #{e.message}")
      []
    end
end

