module Whatsapp::ConversationLock
  # Session-level advisory lock rather than a row lock: handling a message can
  # span a seconds-long LLM call, which has no business sitting inside an open
  # transaction. Postgres drops the lock by itself when the worker dies.
  NAMESPACE = 8_724_301

  module_function

  # Runs the block only when no other worker holds the conversation. Returns
  # false when the lock was busy, so the caller can requeue instead of racing.
  def hold(conversation_id)
    return false if !acquire(conversation_id)

    begin
      yield
    ensure
      release(conversation_id)
    end

    true
  end

  def acquire(conversation_id)
    connection.select_value(statement("pg_try_advisory_lock", conversation_id))
  end

  def release(conversation_id)
    connection.select_value(statement("pg_advisory_unlock", conversation_id))
  end

  def connection
    ActiveRecord::Base.connection
  end

  def statement(function, conversation_id)
    ActiveRecord::Base.sanitize_sql_array(
      ["SELECT #{function}(?, ?)", NAMESPACE, conversation_id]
    )
  end
end
