module TransactionHelper
  # Rule breaks and validation failures roll back quietly; anything else is a bug and raises.
  ALLOWED_EXCEPTIONS = [ActiveRecord::RecordInvalid, BeanBazaar::IllegalMove].freeze

  # Runs the block in a transaction. An allowed exception rolls it back and is kept in
  # @exception, so the service can show its message as the alert.
  def safe_transaction
    ActiveRecord::Base.transaction(requires_new: true) do
      yield
    rescue *ALLOWED_EXCEPTIONS => e
      @exception = e
      raise ActiveRecord::Rollback
    end
  end
end
