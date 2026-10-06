class Api::V1::Accounts::FlowRunsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_flow_run, only: [:show]

  def index
    @flow_runs = Current.account.flow_runs.where(flow_definition_id: params[:flow_definition_id]).order(started_at: :desc)
  end

  def show; end

  private

  def fetch_flow_run
    @flow_run = Current.account.flow_runs.find(params[:id])
  end
end
