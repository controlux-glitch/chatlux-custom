# Shared account-scoped lookups for node handlers that accept a team/agent
# either as a numeric id or a human-readable name/email.
module FlowEngine::Handlers::AccountLookup
  def find_team(account, identifier)
    account.teams.find_by(id: identifier) || account.teams.where(name: identifier.to_s).first
  end

  def find_agent(account, identifier)
    account.users.find_by(id: identifier) || account.users.where(email: identifier.to_s.downcase).first
  end
end
