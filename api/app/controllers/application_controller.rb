class ApplicationController < ActionController::API
  ERROR_CODE_INVALID = "invalid"
  ERROR_CODE_NOT_FOUND = "not_found"
  ERROR_CODE_STALE = "stale"

  private

  def render_validation_errors(record)
    render json: {
      errors: record.errors.map do |error|
        api_error(error.attribute, error.type, error.full_message)
      end
    }, status: :unprocessable_content
  end

  def render_api_error(field:, code:, message:, status:)
    render json: {
      errors: [
        api_error(field, code, message)
      ]
    }, status:
  end

  def render_resource(key, record, serializer:, serializer_options: {}, status: :ok)
    render json: { key => serialize_record(record, serializer:, serializer_options:) }, status:
  end

  def render_collection(key, records, serializer:, serializer_options: {}, meta: nil, status: :ok)
    response_body = {
      key => records.map { |record| serialize_record(record, serializer:, serializer_options:) }
    }
    response_body[:meta] = meta if meta.present?

    render json: response_body, status:
  end

  def api_error(field, code, message)
    {
      field: field.to_s,
      code: code.to_s,
      message:
    }
  end

  def serialize_record(record, serializer:, serializer_options:)
    serializer.new(record, **serializer_options).as_json
  end
end
