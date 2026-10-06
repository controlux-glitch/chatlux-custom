class Api::V1::Accounts::FlowDefinitionsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_flow_definition, only: [:show, :update, :destroy, :publish, :clone]

  def index
    @flow_definitions = Current.account.flow_definitions
  end

  def show; end

  def create
    @flow_definition = Current.account.flow_definitions.new(flow_definition_params.except(:inbox_ids))
    @flow_definition.created_by = Current.user
    @flow_definition.updated_by = Current.user
    @flow_definition.save!
    assign_inboxes(flow_definition_params[:inbox_ids])
  end

  def update
    @flow_definition.updated_by = Current.user
    @flow_definition.update!(flow_definition_params.except(:inbox_ids))
    assign_inboxes(flow_definition_params[:inbox_ids])
  end

  def publish
    @flow_definition.update!(
      status: :published,
      published_definition: @flow_definition.definition,
      version: @flow_definition.version + 1,
      published_at: Time.current,
      updated_by: Current.user
    )
  end

  def clone
    new_flow_definition = @flow_definition.dup
    new_flow_definition.name = "#{@flow_definition.name} (copy)"
    new_flow_definition.status = :draft
    new_flow_definition.published_definition = nil
    new_flow_definition.version = 0
    new_flow_definition.published_at = nil
    new_flow_definition.created_by = Current.user
    new_flow_definition.updated_by = Current.user
    new_flow_definition.save!
    @flow_definition = new_flow_definition
  end

  def destroy
    @flow_definition.destroy!
    head :ok
  end

  private

  # Only inboxes belonging to the current account can ever be linked, even if
  # the client sends foreign ids — prevents cross-account inbox association.
  def assign_inboxes(inbox_ids)
    return if inbox_ids.nil?

    @flow_definition.inbox_ids = Current.account.inboxes.where(id: inbox_ids).ids
  end

  def flow_definition_params
    params.permit(:name, :description, :status, definition: {}, inbox_ids: [])
  end

  def fetch_flow_definition
    @flow_definition = Current.account.flow_definitions.find(params[:id])
  end
end
