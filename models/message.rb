class Message < ActiveRecord::Base
  TYPE_INBOX = 'inbox'
  TYPE_INVITATION = 'invitation'
  TYPE_ALERT = 'alert'

  before_create :create_conversation_group
  after_create :create_message_states, :send_email_notification

  belongs_to :recipient, class_name: 'User', foreign_key: :recipient_id
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  has_many :message_states
  # belongs_to :company

  validates :recipient, presence: true
  validates :body, presence: true

  class << self
    def get_conversation_between_users(user, opponent, offset = 0, limit = nil)
      group = create_conversation_group_between_users(user.id, opponent.id)
      query = query_all_active_by_type(user, self::TYPE_INBOX).where(conversation_group: group)
      .order(created_at: :desc).offset(offset)
      query.limit!(limit) unless limit.nil?
      query
    end

    # def get_conversations(user, offset = 0, limit = nil, exclude_groups = [])
    def get_conversations(user, offset = 0, limit = nil)
      query = select("DISTINCT ON (#{table_name}.conversation_group) #{table_name}.*")
      .joins(:message_states)
      .where(message_states: { user: user, status: MessageState::STATUS_ACTIVE }, type_of: TYPE_INBOX)
      .where.not(conversation_group: nil)
      .order(:conversation_group, created_at: :desc)
      .offset(offset)
      query.limit!(limit) unless limit.nil?
      # query.where!.not(conversation_group: exclude_groups) unless exclude_groups.size.zero?
      query
    end

    def conversations_count(user)
      get_conversations(user, 0)
      .count("DISTINCT ON (#{table_name}.conversation_group) #{table_name}.id")
    end

    def get_invitations(user, offset = 0, limit = nil)
      query = query_all_active_by_type(user, self::TYPE_INVITATION).offset(offset)
      query.limit!(limit) unless limit.nil?
      query
    end

    def get_alerts(user, offset = 0, limit = nil)
      query = query_all_active_by_type(user, self::TYPE_ALERT).offset(offset)
      query.limit!(limit) unless limit.nil?
      query
    end

    # factory methods
    def create_alert(attributes = {})
      attributes[:type_of] = TYPE_ALERT
      attributes.delete(:sender)
      create(attributes)
    end

    def create_invitation(attributes = {})
      attributes[:type_of] = TYPE_INVITATION
      create(attributes)
    end

    def create_inbox(attributes = {})
      attributes[:type_of] = TYPE_INBOX
      create(attributes)
    end

    # fetching methods
    def trashed_count(user)
      query_all_trashed(user).count
    end

    def archived_count(user)
      query_all_archived(user).count
    end

    def inbox_count(user)
      query_all_active_by_type(user, self::TYPE_INBOX).count
    end

    def invitations_count(user)
      query_all_active_by_type(user, self::TYPE_INVITATION).count
    end

    def alerts_count(user)
      query_all_active_by_type(user, self::TYPE_ALERT).count
    end

    def new_count(user)
      query_all_active(user).where(is_read: false).count
    end

    def create_conversation_group_between_users(user_1_id, user_2_id)
      group = [user_1_id.to_i, user_2_id.to_i]
      "#{group.max}_#{group.min}"
    end

    private

    # support queries

    def query_all_active_by_type(user, type)
      query_all_active(user).where(type_of: type)
    end

    def query_all_active(user)
      user_query(user).where(message_states: { status: MessageState::STATUS_ACTIVE })
    end

    def query_all_archived(user)
      user_query(user).where(message_states: { status: MessageState::STATUS_ARCHIVED })
    end

    def query_all_trashed(user)
      user_query(user).where(message_states: { status: MessageState::STATUS_TRASHED })
    end

    # base query
    def user_query(user)
      joins(:message_states).where(message_states: { user: user })
    end
  end

  def get_opponent(for_user)
    if for_user == recipient
      sender
    elsif for_user == sender
      recipient
    end
  end

  def readed?
    is_read
  end

  def wrote_at_formatted
    created_at.strftime('%b %d, %Y - %l:%M %p')
  end

  def type_inbox?
    type_of == TYPE_INBOX
  end

  private

  def create_conversation_group
    return if recipient_id.nil? || sender_id.nil?
    write_attribute(:conversation_group, self.class.create_conversation_group_between_users(recipient_id, sender_id))
  end

  def create_message_states
    sender_state = message_states.create(user: recipient)
    fail 'MessageStates for recipient could not be created.' unless sender_state.persisted?
    return if sender.nil? || type_of == TYPE_INVITATION

    recipient_state = message_states.create(user: sender)
    fail 'MessageStates for sender could not be created.' unless recipient_state.persisted?
  end

  def send_email_notification
    return unless persisted?
    if type_inbox?
      MessageMailer.inbox(self).deliver
    else
      MessageMailer.other_messages(self).deliver
    end
  end
end
