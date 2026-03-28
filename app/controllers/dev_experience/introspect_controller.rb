# frozen_string_literal: true

require "context_record"

module DevExperience
  class IntrospectController < ApplicationController
    skip_forgery_protection

    def create
      bank_id = params.require(:bank_id)
      query = params.require(:query)

      result = Hindsight.client.memories.recall(bank_id, query, budget: "mid")
      render json: result
    rescue Hindsight::Error => e
      render json: { error: e.message }, status: :service_unavailable
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def chat
      question = params.require(:question)
      page_context = params[:context]&.to_unsafe_h || {}

      record = ContextRecord::Record.new(
        action: :execute,
        target: "dx_mirror/chat",
        payload: {
          "question" => ContextRecord::ContextPrimitive.new(type: "vv:Literal", value: question),
          "page" => ContextRecord::ContextPrimitive.new(type: "vv:Entity", value: page_context)
        },
        metadata: { "source" => "dx_mirror" }
      )

      llm = RubyLLM.chat(model: "claude-sonnet-4-5")
      prompt = build_system_prompt(page_context) + "\n\nUser question: " + question
      response = llm.ask(prompt)

      render json: {
        answer: response.content,
        context_record: record.to_json_ld,
        tokens: { input: response.input_tokens, output: response.output_tokens }
      }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def build_system_prompt(ctx)
      parts = []
      parts << "You are a Rails architecture assistant for the DX Mirror source inspector."
      parts << "Answer questions about this page's code, models, controllers, and design."
      parts << ""

      if (ctrl = ctx["controller"]).present?
        parts << "## Controller"
        parts << "- Class: #{ctrl["class_name"]}"
        parts << "- Action: #{ctrl["action"]}"
        parts << "- Before actions: #{(ctrl["before_actions"] || []).join(", ")}"
        parts << "- Params: #{ctrl["params"]&.to_json}"
        parts << "- File: #{ctrl["file_path"]}"
        parts << ""
      end

      if (models = ctx["models"]).present?
        parts << "## Models"
        models.each do |name, info|
          parts << "### #{name} (table: #{info["table"]})"
          if (cols = info["columns"]).present?
            cols.each do |col_name, col_info|
              parts << "  - #{col_name}: #{col_info["type"]}#{col_info["null"] == false ? " NOT NULL" : ""}#{col_info["default"] ? " default=#{col_info["default"]}" : ""}"
            end
          end
          parts << "  Associations: #{(info["associations"] || []).join(", ").presence || "none"}"
          parts << "  File: #{info["file_path"]}"
          parts << ""
        end
      end

      if (views = ctx["views"]).present?
        parts << "## Views"
        parts << "- Template: #{views["template"]}"
        parts << "- Layout: #{views["layout"]}"
        parts << "- Partials: #{(views["partials"] || []).join(", ")}"
        parts << "- Components: #{(views["components"] || []).join(", ")}"
        parts << ""
      end

      if (agentic = ctx["agentic"]).present? && (banks = agentic["banks"]).present?
        parts << "## Agentic Context"
        parts << "- HindSight banks: #{banks.join(", ")}"
        parts << ""
      end

      parts.join("\n")
    end
  end
end
