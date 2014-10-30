class ImagesController < ApplicationController
  before_action :authenticate_user!

  def create
    @image = Image.create(create_params)
    respond
  end

  def crop
    @image = Image.find_by!(id: crop_params['id'], owner: current_user)
    @image.write_crop_attributes(crop_params)
    @image.update_attributes(crop_params)
    respond
  end

  private

  def create_params
    p = params.require(:image).permit(:file)
    # get first file if multiple passed
    p[:file] = p[:file].first if p[:file].class == Array
    p.merge(owner: current_user, entity: entity)
  end

  def crop_params
    params.require(:image).permit(:id, :file_crop_x, :file_crop_y, :file_crop_w, :file_crop_h)
  end

  def entity
    params['preset'].split('_').first.downcase
  end

  # https://github.com/blueimp/jQuery-File-Upload/wiki/Rails-setup-for-V6-(multiple)
  def respond
    # preset comes in url
    preset = params['preset'].to_sym

    if @image.valid?
      respond_to do |format|
        format.html do
          render json: @image.to_jq_upload(preset).to_json,
                 content_type: 'text/html',
                 layout: false
        end
        format.json do
          render json: @image.to_jq_upload(preset)
        end
      end
    else
      render json: [{ error: 'custom_failure' }], status: 304
    end
  end
end
