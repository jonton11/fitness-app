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

  def serialize_time(value)
    value&.utc&.iso8601(3)
  end

  def serialize_decimal(value)
    value&.to_f
  end

  def api_error(field, code, message)
    {
      field: field.to_s,
      code: code.to_s,
      message:
    }
  end
end
