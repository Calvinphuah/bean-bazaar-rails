module RenderShared
  extend ActiveSupport::Concern

  # Renders a service result envelope. Serializer is derived from the payload's
  # class by convention; codes default to 200 / 422.
  # @param result [Hash] { success:, root_name:, payload:, extra_params: }
  def render_result(result, success_code: :ok, error_code: :unprocessable_content)
    if result[:success]
      render_success(result[:payload], result[:root_name], status: success_code, extra_params: result[:extra_params])
    else
      render_error(result[:root_name], status: error_code, extra_params: result[:extra_params])
    end
  end

  # @return [JSON] { <root_name>: <serialized payload with success_message> }
  def render_success(payload, root_name, status:, extra_params: {})
    body = serialize(payload)
    body[:success_message] = extra_params[:success_message] if extra_params[:success_message].present?

    render json: { root_name => body }, status: status
  end

  # @return [JSON] { <root_name>: { error_message } }
  def render_error(root_name, status:, extra_params: {})
    render json: { root_name => { error_message: extra_params[:alert] } }, status: status
  end

  # @return [Hash]
  def serialize(payload)
    serializer_for(payload).new(payload).as_json
  end

  # Derives the serializer from the payload class within the controller's
  # namespace, e.g. Api::GameSerializer for a Game in Api.
  def serializer_for(payload)
    namespace = self.class.name.deconstantize
    "#{namespace}::#{payload.class.name}Serializer".constantize
  end
end
