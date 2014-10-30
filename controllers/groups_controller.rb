class Api::GroupsController < ApplicationController

  skip_before_action :verify_authenticity_token, only: [:create, :update, :destroy, :restore]
  before_action :authenticate_user!
  load_and_authorize_resource only: [:update, :destroy, :restore]

  def index
    current_user.remove_deleted_groups
    @groups =
        if params[:owned]
          Group.owned_by(current_user).order(name: :asc)
        else
          Group.including(current_user).order(name: :asc)
        end
  end

  def query
    @groups = Group.including(current_user)
      .where('name LIKE ?', "%#{params[:q]}%")
      .where.not(id: params[:selected_groups] || [])
      .first(10)
  end

  def owned
    @groups = Group.owned_by(current_user)
      .where('name LIKE ?', "%#{params[:q]}%",)
      .order(updated_at: :desc)
      .first(10)
    render :query
  end

  def create
    options = group_params
    @group = Group.new
    @group.name = options[:name]
    @group.owner = current_user
    if @group.save
      @group.update_users(options[:users])
    end
    response.status = 422 unless @group.valid?
    render :show
  end

  def update
    options = group_params
    @group.name = options[:name]
    if @group.save
      @group.update_users(options[:users])
    end
    response.status = 422 unless @group.valid?
    render :show
  end

  def destroy
    @group.update_attribute(:is_deleted, true)
    render :show
  end

  def restore
    @group.update_attribute(:is_deleted, false)
    render :show
  end

  private

  def group_params
    params.permit(:name, users: [])
  end

end
