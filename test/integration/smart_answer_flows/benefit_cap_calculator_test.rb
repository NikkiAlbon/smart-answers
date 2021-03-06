require_relative "../../test_helper"
require_relative "flow_test_helper"
require "gds_api/test_helpers/imminence"

require "smart_answer_flows/benefit-cap-calculator"

class BenefitCapCalculatorTest < ActiveSupport::TestCase
  include FlowTestHelper
  include GdsApi::TestHelpers::Imminence

  setup do
    setup_for_testing_flow SmartAnswer::BenefitCapCalculatorFlow

    stub_imminence_has_areas_for_postcode("WC2B%206SE", [{ type: "EUR", name: "London", country_name: "England" }])
    stub_imminence_has_areas_for_postcode("B1%201PW", [{ type: "EUR", name: "West Midlands", country_name: "England" }])
  end

  context "Benefit cap calculator" do
    context "when using post-Autumn 2016 rates and rules" do
      # setup { add_response :default }

      #Q1 Receiving Housing Benefit
      should "ask do you receive housing benefit" do
        assert_current_node :receive_housing_benefit?
      end

      context "answer yes" do
        setup { add_response :yes }

        #Q2 Qualify for working tax credit
        should "ask if qualify for working tax credit" do
          assert_current_node :working_tax_credit?
        end

        context "answer yes" do
          setup { add_response :yes }

          should "go to Outcome 1" do
            assert_current_node :outcome_not_affected_exemptions
          end
        end # Q2 Qualify for working tax credit at Outcome 1

        ## Not qualify for working tax credit from Q3
        context "answer no" do
          setup { add_response :no }

          #Q3
          should "Ask if household receiving exemption benefits" do
            assert_current_node :receiving_exemption_benefits?
          end

          context "selects more than one exempt benefit" do
            setup { add_response "attendance_allowance,war_pensions" }

            should "go to outcome 1" do
              assert_current_node :outcome_not_affected_exemptions
            end
          end

          context "selects at least one exempt benefit" do
            setup { add_response :attendance_allowance }

            should "go to outcome 1" do
              assert_current_node :outcome_not_affected_exemptions
            end
          end # Q3 receiving benefits end at Outcome 1

          # not receiving exemption benefits from Q3
          context "does not select any exempt benefit" do
            setup { add_response :none }

            #Q4
            should "ask if household receiving other benefits" do
              assert_current_node :receiving_non_exemption_benefits?
            end

            context "answer receiving additional benefits" do
              setup { add_response "incapacity,sda" }

              #Q5f
              should "ask how much for incapacity allowance benefit" do
                assert_state_variable :benefit_types, [:sda]
                assert_current_node :incapacity_amount?
                assert_state_variable :total_benefits, 0
              end

              context "answer incapacity allowance amount" do
                setup { add_response "300" }

                #Q5k
                should "ask how much for severe disability allowance" do
                  assert_state_variable :benefit_types, []
                  assert_current_node :sda_amount?
                  assert_state_variable :total_benefits, 300
                end

                context "answer sda amount" do
                  setup { add_response "300" }

                  #Q5p
                  should "ask how much for housing benefit" do
                    assert_state_variable :benefit_types, []
                    assert_state_variable :total_benefits, 600
                    assert_current_node :housing_benefit_amount?
                  end

                  context "answer housing benefit amount" do
                    setup { add_response "300" }

                    #Q6
                    should "ask whether single, living with couple or lone parent" do
                      assert_current_node :single_couple_lone_parent?
                    end

                    context "answer single above cap" do
                      setup { add_response "single" }

                      should "ask for postcode" do
                        assert_current_node :enter_postcode?
                      end

                      context "answer postcode question with London postcode" do
                        setup { add_response "WC2B 6SE" }

                        should "go to outcome 3" do
                          assert_current_node :outcome_affected_greater_than_cap_london
                        end
                      end

                      context "answer postcode question with Birmingham postcode" do
                        setup { add_response "B1 1PW" }

                        should "go to outcome 3" do
                          assert_current_node :outcome_affected_greater_than_cap_national
                        end
                      end
                    end #Q6 single greater than cap, at Outcome 3
                  end #Q5p how much for housing benefit
                end #Q5k how much for severe disablity allowance
              end #Q5f how much for guardian allowance benefit
            end #Q4 receiving additional benefits, above cap

            context "answer receiving additional benefits" do
              setup { add_response "esa,maternity" }

              should "ask ask how much for esa benefit" do
                assert_state_variable :benefit_types, [:maternity]
                assert_current_node :esa_amount?
              end

              context "answer esa amount" do
                setup { add_response "10" }

                should "ask how much for maternity benefits" do
                  assert_state_variable :benefit_types, []
                  assert_current_node :maternity_amount?
                end

                context "answer maternity amount" do
                  setup { add_response "10" }

                  should "ask how much for housing benefits" do
                    assert_state_variable :benefit_types, []
                    assert_current_node :housing_benefit_amount?
                  end

                  context "answer housing benefit amount" do
                    setup { add_response "10" }

                    should "ask if single, couple or lone parent" do
                      assert_current_node :single_couple_lone_parent?
                    end

                    context "answer lone parent" do
                      setup { add_response "parent" }

                      should "ask for postcode" do
                        assert_current_node :enter_postcode?
                      end

                      context "answer postcode question with London postcode" do
                        setup { add_response "WC2B 6SE" }

                        should "go to outcome" do
                          assert_current_node :outcome_not_affected_less_than_cap_london
                        end
                      end

                      context "answer postcode question with Birmingham postcode" do
                        setup { add_response "B1 1PW" }

                        should "go to outcome" do
                          assert_current_node :outcome_not_affected_less_than_cap_national
                        end
                      end
                    end #Q6 lone parent, under cap, at Outcome 4
                  end #Q5p how much for housing, under cap
                end #Q5j how much for maternity, under cap
              end #Q5e how much for esa, under cap
            end #Q4 receiving additional benefits, under cap

            # not receiving additional benefits from Q4
            context "no additional benefits selected" do
              setup { add_response "none" }

              should "ask for housing benefit amount" do
                assert_current_node :housing_benefit_amount?
              end

              context "answer housing benefit amount" do
                setup { add_response "10" }

                should "ask if single, couple or lone parent" do
                  assert_current_node :single_couple_lone_parent?
                end

                context "answer lone parent" do
                  setup { add_response "parent" }

                  should "ask for your postcode" do
                    assert_current_node :enter_postcode?
                  end
                  context "enter postcode outside London" do
                    setup { add_response "B1 1PW" }

                    should "go to outcome benefits less than cap for outside London" do
                      assert_current_node :outcome_not_affected_less_than_cap_national
                    end
                  end
                  context "enter postcode in Greater London" do
                    setup { add_response "WC2B 6SE" }

                    should "go to outcome benefits less than cap for Greater London" do
                      assert_current_node :outcome_not_affected_less_than_cap_london
                    end
                  end
                end #Q6 lone parent, under cap, at Outcome 4
              end #Q5p how much for housing, under cap
            end #Q4 no additional benefits at Outcome 5
          end #Q3 not receiving benefits
        end # Q2 not qualify for working tax credit
      end # Q1 Receiving housing benefit

      # Not receiving housing benefit
      context "answer no" do
        setup { add_response :no }

        should "go to Outcome 1" do
          assert_current_node :outcome_not_affected_no_housing_benefit
        end
      end # Q1 not receving housing benefit at Outcome 2

      context "housing benefit less than 0.5" do
        should "show :outcome_affected_greater_than_cap outcome" do
          add_response :yes
          add_response :no
          add_response :none
          add_response :child_benefit
          add_response "100"
          add_response "400"
          add_response :single
          add_response "WC2B 6SE"
          assert_current_node :outcome_affected_greater_than_cap_london
        end
      end
    end
  end
end # BenefitCapCalculatorTest
