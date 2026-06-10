module Admin
  class SponsorsController < BaseController
    before_action :set_sponsor, only: [:edit, :update, :destroy]

    def index
      @sponsors = Sponsor.order(:name)
    end

    def new
      @sponsor = Sponsor.new
    end

    def create
      @sponsor = Sponsor.new(sponsor_attributes)

      if @sponsor.save
        redirect_to admin_sponsors_path, notice: "Sponsor was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @sponsor.update(sponsor_attributes)
        redirect_to admin_sponsors_path, notice: "Sponsor was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sponsor.destroy
      redirect_to admin_sponsors_path, notice: "Sponsor was successfully deleted."
    end

    private

    def set_sponsor
      @sponsor = Sponsor.find(params[:id])
    end

    def sponsor_params
      params.require(:sponsor).permit(:name, :website, :description, :logo, social_media_links: {})
    end

    def sponsor_attributes
      attributes = sponsor_params.to_h
      attributes["social_media_links"] = normalized_social_media_links(attributes["social_media_links"])
      attributes
    end

    def normalized_social_media_links(value)
      return value unless value.is_a?(Hash)

      value.transform_values { |link| link.to_s.strip }.reject { |_platform, link| link.blank? }
    end
  end
end
