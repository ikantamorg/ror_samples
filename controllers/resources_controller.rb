class JobSeekers::Profiles::Resources::ResourcesController < JobSeekers::JobSeekerController

  skip_before_action :verify_authenticity_token

  before_action :set_resource, only: [:show, :update, :destroy]

  def show
    # renders default template
  end

  def create
    @resource = klass.create(resource_params)
    render_create_or_update
  end

  def update
    @resource.update_attributes(resource_params)
    render_create_or_update
  end

  def destroy
    @resource.destroy
    render_create_or_update
  end

  def autocomplete
    @field = autocomplete_params['field']
    @query = autocomplete_params['query']
    @resources = klass.where(@field + ' ILIKE ?', "%#{@query}%").limit(5)
    render 'job_seekers/profiles/resources/autocomplete'
  end

  protected

  # methods to override

  def klass
    raise 'Must be overriden with the name of the class'
  end

  def views_folder
    raise 'Must be overriden with views folder'
  end

  def resource_params
    raise 'Must be overriden with custom params handler'
  end

  def autocomplete_params
    params.permit(:field, :query)
  end

  # common methods

  def set_resource
    @resource = klass.find_by!({
      id: params[:id],
      job_seeker: @job_seeker
    })
  end

  def render_create_or_update
    if @resource.valid?
      render "job_seekers/profiles/resources/#{views_folder}/show"
    else
      render 'job_seekers/profiles/resources/errors', status: 422
    end
  end

end