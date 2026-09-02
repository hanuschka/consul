# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Poll Questions API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path "/api/polls/{poll_id}/questions" do
    parameter name: :poll_id, in: :path, type: :integer, description: "Poll ID"

    get "List questions for a poll" do
      tags "Poll Questions"
      produces "application/json"
      security [bearer_auth: []]
      description "List all questions within a specific poll. Returns questions with their answers, paginated with pagination metadata. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: "Page number (**default:** 1)", required: false
      parameter name: :per_page, in: :query, type: :integer, description: "Items per page (**default:** 100)", required: false

      response "200", "questions found" do
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }

        before do
          author = create_admin_user
          create_poll_question(poll, title: "Question 1", author: author)
          create_poll_question(poll, title: "Question 2", author: author)
          api_client.update!(access_level: :public_data)
          api_client.update!(access_level: :public_data)
          api_client.update!(access_level: :public_data)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     questions: {
                       type: :array,
                       items: { "$ref" => "#/components/schemas/PollQuestion" }
                     }
                   },
                   required: ["questions"]
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ["data"]

        run_test!
      end

      response "404", "poll not found" do
        let(:poll_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:poll_id) { 1 } }
    end

    post "Create a poll question" do
      tags "Poll Questions"
      consumes "application/json"
      produces "application/json"
      security [bearer_auth: []]
      description "Create a new question within a poll. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :question, in: :body, description: "Poll question creation payload",
schema: Schemas::Polls::POLL_QUESTION_CREATE_PARAMS

      response "201", "question created" do
        let!(:administrator) { create_admin_user }
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          {
            question: {
              translations_attributes: [
                { locale: "en", title: "What is your preference?" },
                { locale: "de", title: "Was ist Ihre Praeferenz?" }
              ],
              multiple: false
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test!
      end

      response "201", "question created with randomized answers and position" do
        let!(:administrator) { create_admin_user }
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          {
            question: {
              translations_attributes: [
                { locale: "en", title: "Randomized question" },
                { locale: "de", title: "Zufaellige Frage" }
              ],
              randomize_answers: true,
              randomize_position: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["question"]["randomize_answers"]).to eq(true)
          expect(data["data"]["question"]["randomize_position"]).to eq(true)
        end
      end

      response "201", "randomize_position refused on a bundle question" do
        let!(:administrator) { create_admin_user }
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          {
            question: {
              translations_attributes: [{ locale: "en", title: "Bundle question" }],
              bundle_question: true,
              randomize_position: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["question"]["randomize_position"]).to eq(false)
        end
      end

      response "201", "bundle question created" do
        let!(:administrator) { create_admin_user }
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          {
            question: {
              translations_attributes: [
                { locale: "en", title: "Bundle question title" },
                { locale: "de", title: "Bündelfrageüberschrift" }
              ],
              bundle_question: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["data"]["question"]["bundle_question"]).to eq(true)
        end
      end

      response "422", "invalid request" do
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          { question: { translations_attributes: [{ locale: "en", title: "" }] }}
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string }}
                   }
                 }
               }

        run_test!
      end

      response "403", "forbidden - admin access required" do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:poll_id) { poll.id }
        let(:question) do
          {
            question: {
              translations_attributes: [
                { locale: "en", title: "Test question?" }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string }}
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["type"]).to eq("forbidden")
        end
      end

      unauthorized_response { let(:poll_id) { 1 } }
    end
  end

  path "/api/poll_questions/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "Poll Question ID"

    get "Retrieve a poll question" do
      tags "Poll Questions"
      produces "application/json"
      security [bearer_auth: []]
      description "Retrieve a specific poll question by ID with its answers. #{ApiAccessRequirements::GET_READ_ONLY}"

      response "200", "question found" do
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:author) { create_admin_user }
        let(:poll_question) { create_poll_question(poll, title: "Test Question", author: author) }
        let(:id) { poll_question.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test!
      end

      response "404", "question not found" do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch "Update a poll question" do
      tags "Poll Questions"
      consumes "application/json"
      produces "application/json"
      security [bearer_auth: []]
      description "Update an existing poll question. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :question, in: :body, description: "Attributes to update on the poll question",
schema: Schemas::Polls::POLL_QUESTION_UPDATE_PARAMS

      response "200", "question updated" do
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:author) { create_admin_user }
        let(:poll_question) { create_poll_question(poll, title: "Original Title", author: author) }
        let(:id) { poll_question.id }
        let(:question) do
          {
            question: {
              multiple: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question: { "$ref" => "#/components/schemas/PollQuestion" }
                   },
                   required: ["question"]
                 }
               },
               required: ["data"]

        run_test!
      end

      response "403", "forbidden - admin access required" do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:author) { create_admin_user }
        let(:poll_question) { create_poll_question(poll, title: "Test", author: author) }
        let(:id) { poll_question.id }
        let(:question) do
          { question: { multiple: true }}
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string }}
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["type"]).to eq("forbidden")
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete "Delete a poll question" do
      tags "Poll Questions"
      produces "application/json"
      security [bearer_auth: []]
      description "Delete a poll question and all its answers. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response "200", "question deleted" do
        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:author) { create_admin_user }
        let(:poll_question) { create_poll_question(poll, title: "To Delete", author: author) }
        let(:id) { poll_question.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ["message"]

        run_test!
      end

      response "404", "question not found" do
        let(:id) { 999999 }

        run_test!
      end

      response "403", "forbidden - admin access required" do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: "Projekt") }
        let(:voting_phase) { projekt.projekt_phases.create!(type: "ProjektPhase::VotingPhase", active: true) }
        let(:poll) { voting_phase.polls.create!(name: "Test Poll") }
        let(:author) { create_admin_user }
        let(:poll_question) { create_poll_question(poll, title: "Test", author: author) }
        let(:id) { poll_question.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string }}
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["type"]).to eq("forbidden")
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end
