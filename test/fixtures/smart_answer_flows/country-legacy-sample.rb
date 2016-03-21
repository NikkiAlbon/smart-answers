module SmartAnswer
  class CountryLegacySampleFlow < Flow
    def define
      name 'country-legacy-sample'
      status :draft

      country_select :which_country_do_you_live_in?, use_legacy_data: true do
        save_input_as :country
        next_node do
          question :which_country_were_you_born_in?
        end
      end

      country_select :which_country_were_you_born_in?, include_uk: true, use_legacy_data: true do
        save_input_as :country_of_birth
        next_node do
          outcome :ok
        end
      end

      outcome :ok
    end
  end
end
