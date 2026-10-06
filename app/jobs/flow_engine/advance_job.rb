# Advances one FlowRun by one "tick". Idempotent under concurrent enqueues:
# a token-based Redis lock (same pattern as AutoAssignment::AssignmentJob,
# not the non-owner-checked Redis::LockManager) guarantees only one worker
# advances a given flow_run at a time, and the flow_run's own status is
# re-checked inside the lock before doing any work.
class FlowEngine::AdvanceJob < ApplicationJob
  queue_as :default

  LOCK_TTL = 30.seconds

  def perform(flow_run_id, resume_message_id: nil)
    key = format(Redis::Alfred::FLOW_RUN_MUTEX, flow_run_id: flow_run_id)
    token = SecureRandom.uuid
    return unless Redis::Alfred.set(key, token, nx: true, ex: LOCK_TTL)

    begin
      run_flow(flow_run_id, resume_message_id)
    ensure
      Redis::Alfred.delete_if_equals(key, token)
    end
  end

  private

  def run_flow(flow_run_id, resume_message_id)
    flow_run = FlowRun.find_by(id: flow_run_id)
    return if flow_run.nil? || !flow_run.active?

    resume_message = resume_message_id.present? ? Message.find_by(id: resume_message_id) : nil
    FlowEngine::Runner.new(flow_run).advance(resume_message: resume_message)
  rescue StandardError => e
    Rails.logger.error("[FlowEngine::AdvanceJob] flow_run=#{flow_run_id} #{e.class}: #{e.message}")
    raise e if Rails.env.test?
  end
end
