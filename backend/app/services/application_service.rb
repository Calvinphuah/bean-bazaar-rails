class ApplicationService
  include TransactionHelper

  # initialize for most of the services to track whether the service succeeded
  def initialize
    @success = false
    @exception = nil
  end

  # @param success [Boolean] result success or fail
  # @param root_name [Symbol] root_name for api response
  # @param payload [ApplicationRecord] the model the controller serializes
  # @param extra_params [Hash] success_message, alert and any extras for the api response
  # @return [Hash] { success:, root_name:, payload:, extra_params: }
  def return_result(success, root_name, payload, extra_params: {})
    { success: success, root_name: root_name, payload: payload, extra_params: extra_params.presence || {} }
  end
end
