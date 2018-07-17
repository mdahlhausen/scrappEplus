# start the measure
class TransferAirZoneMixing < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Transfer Air Zone Mixing"
  end
  # human readable description
  def description
    return "This measure models air transfering from a source zone to receiving zone.  It asks the user to specify the flow rate, zone, and source zone.  Schedule limits for flow rate, and minimum and maximum temperatures for source zone, receiving zone, and outdoor air temperatures can be input, as described in the EnergyPlus InputOutput reference. This measure will also add a dummy zone exhaust fan to the source zone to subtract the flow from the return air of that zone.  The balancing of the source zone supply, return, and transfer flows is the user's responsibility."
  end
  # human readable description of modeling approach
  def modeler_description
    return "This measure models air transfering from a source zone to receiving zone using the ZoneMixing object.  It asks the user to specify the flow rate, zone, and source zone.  Schedule limits for flow rate, and minimum and maximum temperatures for source zone, receiving zone, and outdoor air temperatures can be input, as described in the EnergyPlus InputOutput reference. This measure will also add a dummy FanZoneExhaust object to the source zone to subtract the flow from the return air of that zone.  The balancing of the source zone supply, return, and transfer flows is the user's responsibility."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # populate zones choice argument
    zones_hash = {}
    model.getThermalZones.each do |zone|
      zones_hash[zone.name.to_s] = zone
    end
    zone_handles = OpenStudio::StringVector.new
    zone_display_names = OpenStudio::StringVector.new
    zones_hash.sort.map do |zone_name, zone|
      zone_handles << zone.handle.to_s
      zone_display_names << zone.name.to_s
    end

    # make an argument the receiving zone
    receiving_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("receiving_zone", zone_handles, zone_display_names,true)
    receiving_zone.setDisplayName("Choose the Receiving Zone:")
    args << receiving_zone

    # make an argument the source zone
    source_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("source_zone", zone_handles, zone_display_names,true)
    source_zone.setDisplayName("Choose the Source Zone:")
    args << source_zone

    # make an argument to choose which flow rate method to use
    flow_rate_method_choices = OpenStudio::StringVector.new
    flow_rate_method_choices << "Flow (m3/s)"
    flow_rate_method_choices << "Flow per area of receiving zone (m3/s-m2)"
    flow_rate_method_choices << "Flow per area of source zone (m3/s-m2)"
    flow_rate_method_choices << "Flow per person of receiving zone (m3/s-person)"
    flow_rate_method_choices << "Flow per person of source zone (m3/s-person)"
    flow_rate_method_choices << "Air changes per hour of receiving zone (ACH)"
    flow_rate_method_choices << "Air changes per hour of source zone (ACH)"
    flow_rate_method_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("flow_rate_method_choice", flow_rate_method_choices, true)
    flow_rate_method_choice.setDisplayName("Choose a flow rate method to use:")
    flow_rate_method_choice.setDefaultValue("Flow (m3/s)")
    args << flow_rate_method_choice

    # make an argument for the flow rate matching the flow rate method chosen above
    flow_value = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("flow_value", true)
    flow_value.setDisplayName("Flow value for the flow rate method chosen:")
    flow_value.setDescription("Remember to convert IP to SI units.")
    flow_value.setDefaultValue(0.0)
    args << flow_value

    #populate choice argument for temperature schedules in the model
    flow_sch_handles = OpenStudio::StringVector.new
    flow_sch_display_names = OpenStudio::StringVector.new

    #putting schedule names into hash
    flow_sch_hash = {}
    model.getSchedules.each do |sch|
      if not sch.scheduleTypeLimits.empty?
        if sch.scheduleTypeLimits.get.name.to_s.include? "Fractional"
          flow_sch_hash[sch.name.to_s] = sch
        elsif sch.scheduleTypeLimits.get.unitType.to_s.include? "Availability"
          flow_sch_hash[sch.name.to_s] = sch
        end
      end
    end

    #looping through sorted hash of schedules
    flow_sch_hash.sort.map do |sch_name, sch|
      flow_sch_handles << sch.handle.to_s
      flow_sch_display_names << sch_name
    end

    #make an argument for delta temperature schedule
    flow_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("flow_sch", flow_sch_handles, flow_sch_display_names, false)
    flow_sch.setDisplayName("Select Schedule to Modify the Flow Rate (optional, default is always 1.0):")
    args << flow_sch
    
    #populate choice argument for temperature schedules in the model
    temp_sch_handles = OpenStudio::StringVector.new
    temp_sch_display_names = OpenStudio::StringVector.new

    #putting schedule names into hash
    temp_sch_hash = {}
    model.getSchedules.each do |sch|
      temp_sch_hash[sch.name.to_s] = sch
    end
    
    temp_sch_hash.sort.map do |sch_name, sch|
      if not sch.scheduleTypeLimits.empty?
        unitType = sch.scheduleTypeLimits.get.unitType
        if unitType == "Temperature"
          temp_sch_handles << sch.handle.to_s
          temp_sch_display_names << sch_name
        end
      end
    end

    # make an argument for the flow rate matching the flow rate method chosen above
    delta_temp = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("delta_temp", false)
    delta_temp.setDisplayName("Set the Delta Temperature (optional):")
    delta_temp.setDescription("Remember to convert IP to SI units.")
    delta_temp.setDefaultValue(0.0)
    args << delta_temp

    #make an argument for delta temperature schedule
    delta_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("delta_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    delta_temp_sch.setDisplayName("Select Delta Temperature Schedule (optional):")
    args << delta_temp_sch

    #make an argument for minimum receiving zone temperature schedule
    min_rec_zone_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("min_rec_zone_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    min_rec_zone_temp_sch.setDisplayName("Select Minimum Receiving Zone Temperature Schedule (optional):")
    args << min_rec_zone_temp_sch

    #make an argument for maximum receiving zone temperature schedule
    max_rec_zone_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("max_rec_zone_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    max_rec_zone_temp_sch.setDisplayName("Select Maximum Receiving Zone Temperature Schedule (optional):")
    args << max_rec_zone_temp_sch

    #make an argument for minimum source zone temperature schedule
    min_source_zone_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("min_source_zone_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    min_source_zone_temp_sch.setDisplayName("Select Minimum Source Zone Temperature Schedule (optional):")
    args << min_source_zone_temp_sch

    #make an argument for maximum source zone temperature schedule
    max_source_zone_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("max_source_zone_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    max_source_zone_temp_sch.setDisplayName("Select Maximum Source Zone Temperature Schedule (optional):")
    args << max_source_zone_temp_sch
    
    #make an argument for minimum outdoor air temperature schedule
    min_oa_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("min_oa_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    min_oa_temp_sch.setDisplayName("Select Minimum Outdoor Air Temperature Schedule (optional):")
    args << min_oa_temp_sch
    
    #make an argument for maximum outdoor air temperature schedule
    max_oa_temp_sch = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("max_oa_temp_sch", temp_sch_handles, temp_sch_display_names, false)
    max_oa_temp_sch.setDisplayName("Select Maximum Outdoor Air Temperature Schedule (optional):")
    args << max_oa_temp_sch
    
    # optionally add zone exhaust fan to source zone
    add_zone_exhaust_fan = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_zone_exhaust_fan", true)
    add_zone_exhaust_fan.setDisplayName("Add Source Zone Exhaust Fan (recommended)")
    add_zone_exhaust_fan.setDefaultValue(true)
    args << add_zone_exhaust_fan

    # optionally add zone exhaust fan to source zone
    couple_zone_exhaust_fan = OpenStudio::Ruleset::OSArgument.makeBoolArgument("couple_zone_exhaust_fan", true)
    couple_zone_exhaust_fan.setDisplayName("Couple Source Zone Exhaust Fan to Source Zone System Availability Manager (recommended)")
    couple_zone_exhaust_fan.setDefaultValue(true)
    args << couple_zone_exhaust_fan

    # optionally add zone mixing output variables
    add_zone_mixing_variables = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_zone_mixing_variables", true)
    add_zone_mixing_variables.setDisplayName("Add Zone Mixing Output Variable Requests")
    add_zone_mixing_variables.setDefaultValue(true)
    args << add_zone_mixing_variables

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    receiving_zone = runner.getOptionalWorkspaceObjectChoiceValue("receiving_zone",user_arguments,model)
    source_zone = runner.getOptionalWorkspaceObjectChoiceValue("source_zone",user_arguments,model)
    flow_rate_method_choice = runner.getOptionalStringArgumentValue("flow_rate_method_choice", user_arguments)
    flow_value = runner.getDoubleArgumentValue("flow_value", user_arguments)
    flow_sch = runner.getOptionalWorkspaceObjectChoiceValue("flow_sch",user_arguments,model)
    delta_temp = runner.getDoubleArgumentValue("delta_temp", user_arguments)
    delta_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("delta_temp_sch",user_arguments,model)
    min_rec_zone_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("min_rec_zone_temp_sch",user_arguments,model)
    max_rec_zone_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("max_rec_zone_temp_sch",user_arguments,model)
    min_source_zone_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("min_source_zone_temp_sch",user_arguments,model)
    max_source_zone_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("max_source_zone_temp_sch",user_arguments,model)
    min_oa_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("min_oa_temp_sch",user_arguments,model)
    max_oa_temp_sch = runner.getOptionalWorkspaceObjectChoiceValue("max_oa_temp_sch",user_arguments,model)
    add_zone_exhaust_fan = runner.getBoolArgumentValue("add_zone_exhaust_fan", user_arguments)
    couple_zone_exhaust_fan = runner.getBoolArgumentValue("couple_zone_exhaust_fan", user_arguments)
    add_zone_mixing_variables = runner.getBoolArgumentValue("add_zone_mixing_variables", user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getZoneMixings.size} Zone Mixing Objects.")

    if not receiving_zone.get.to_ThermalZone.empty?
      receiving_zone = receiving_zone.get.to_ThermalZone.get
    else
      runner.registerError("Script Error - receiving zone not showing up as a Thermal Zone.")
      return false
    end

    if not source_zone.get.to_ThermalZone.empty?
      source_zone = source_zone.get.to_ThermalZone.get
    else
      runner.registerError("Script Error - source zone not showing up as a Thermal Zone.")
      return false
    end
    
    # get zone volumes and areas for later use
    receiving_zone_volume = 0
    receiving_zone_area = 0
    receiving_zone_ppl = 0
    receiving_zone.spaces.each do |space|
      receiving_zone_volume += space.volume
      receiving_zone_area += space.floorArea
      receiving_zone_ppl += space.numberOfPeople
    end

    source_zone_volume = 0
    source_zone_area = 0
    source_zone_ppl = 0
    source_zone.spaces.each do |space|
      source_zone_volume += space.volume
      source_zone_area += space.floorArea
      source_zone_ppl += space.numberOfPeople      
    end
    
    #create zone mixing object
    zone_mixing_object = OpenStudio::Model::ZoneMixing.new(receiving_zone)
    zone_mixing_object.setName("#{source_zone} to #{receiving_zone} Air Transfer Zone Mixing")
    zone_mixing_object.setSourceZone(source_zone)
    zone_mixing_object.setDeltaTemperature(delta_temp) #default is 0.0

    exhaust_flow_rate = 0
    #set parameters depending on flow method
    if flow_rate_method_choice.to_s == "Flow (m3/s)"        
      zone_mixing_object.setDesignFlowRate(flow_value)
      exhaust_flow_rate = flow_value
    elsif flow_rate_method_choice.to_s == "Flow per area of receiving zone (m3/s-m2)"
      zone_mixing_object.setFlowRateperZoneFloorArea(flow_value)
      exhaust_flow_rate = flow_value*receiving_zone_area
    elsif flow_rate_method_choice.to_s == "Flow per area of source zone (m3/s-m2)" 
      exhaust_flow_rate = flow_value*source_zone_area
      zone_mixing_object.setDesignFlowRate(exhaust_flow_rate)      
    elsif flow_rate_method_choice.to_s == "Flow per person of receiving zone (m3/s-person)"
      zone_mixing_object.setFlowRateperPerson(flow_value)
      exhaust_flow_rate = flow_value*receiving_zone_ppl
    elsif flow_rate_method_choice.to_s == "Flow per person of source zone (m3/s-person)"
      exhaust_flow_rate = flow_value*source_zone_ppl
      zone_mixing_object.setDesignFlowRate(exhaust_flow_rate)      
    elsif flow_rate_method_choice.to_s == "Air changes per hour of receiving zone (ACH)"      
      zone_mixing_object.setAirChangesperHour(flow_value)
      exhaust_flow_rate = flow_value*receiving_zone_volume/3600.0
    elsif flow_rate_method_choice.to_s == "Air changes per hour of source zone (ACH)"      
      exhaust_flow_rate = flow_value*source_zone_volume/3600.0
      zone_mixing_object.setDesignFlowRate(exhaust_flow_rate)      
    end
    runner.registerInfo("Add zone mixing between #{receiving_zone.name} and #{source_zone.name} with flowrate of #{flow_value} #{flow_rate_method_choice}")

    #set schedules if defined
    if not flow_sch.empty?
      if not flow_sch.get.to_Schedule.empty?
        flow_sch = flow_sch.get.to_Schedule.get
        zone_mixing_object.setSchedule(flow_sch)
        runner.registerInfo("Zone Mixing Object Flow Schedule set to #{flow_sch.name.to_s}")
      else
        runner.registerError("Script Error - Flow Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not delta_temp_sch.empty?
      if not delta_temp_sch.get.to_Schedule.empty?
        delta_temp_sch = delta_temp_sch.get.to_Schedule.get
        zone_mixing_object.setDeltaTemperatureSchedule(delta_temp_sch)
        runner.registerInfo("Zone Mixing Object Delta Temperature Schedule set to #{delta_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Delta Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not min_rec_zone_temp_sch.empty?
      if not min_rec_zone_temp_sch.get.to_Schedule.empty?
        min_rec_zone_temp_sch = min_rec_zone_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMinimumZoneTemperatureSchedule(min_rec_zone_temp_sch)
        runner.registerInfo("Zone Mixing Object Minimum Receiving Zone Temperature Schedule set to #{min_rec_zone_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Minimum Receiving Zone Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not max_rec_zone_temp_sch.empty?
      if not max_rec_zone_temp_sch.get.to_Schedule.empty?
        max_rec_zone_temp_sch = max_rec_zone_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMaximumZoneTemperatureSchedule(max_rec_zone_temp_sch)
        runner.registerInfo("Zone Mixing Object Maximum Receiving Zone Temperature Schedule set to #{max_rec_zone_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Maximum Receiving Zone Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not min_source_zone_temp_sch.empty?
      if not min_source_zone_temp_sch.get.to_Schedule.empty?
        min_source_zone_temp_sch = min_source_zone_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMinimumSourceZoneTemperatureSchedule(min_source_zone_temp_sch)
        runner.registerInfo("Zone Mixing Object Minimum Source Zone Temperature Schedule set to #{min_source_zone_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Minimum Source Zone Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not max_source_zone_temp_sch.empty?
      if not max_source_zone_temp_sch.get.to_Schedule.empty?
        max_source_zone_temp_sch = max_source_zone_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMaximumSourceZoneTemperatureSchedule(max_source_zone_temp_sch)
        runner.registerInfo("Zone Mixing Object Maximum Source Zone Temperature Schedule set to #{max_source_zone_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Maximum Source Zone Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not min_oa_temp_sch.empty?
      if not min_oa_temp_sch.get.to_Schedule.empty?
        min_oa_temp_sch = min_oa_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMinimumOutdoorTemperatureSchedule(min_oa_temp_sch)
        runner.registerInfo("Zone Mixing Object Minimum Outdoor Air Temperature Schedule set to #{min_oa_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Minimum Outdoor Air Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end

    if not max_oa_temp_sch.empty?
      if not max_oa_temp_sch.get.to_Schedule.empty?
        max_oa_temp_sch = max_oa_temp_sch.get.to_Schedule.get
        zone_mixing_object.setMaximumOutdoorTemperatureSchedule(max_oa_temp_sch)
        runner.registerInfo("Zone Mixing Object Maximum Outdoor Air Temperature Schedule set to #{max_oa_temp_sch.name.to_s}")
      else
        runner.registerError("Script Error - Maximum Outdoor Air Temperature Schedule argument not showing up as schedule.")
        return false
      end
    end      
     
    # add zone exhaust fan with the same schedule if defined  
    if add_zone_exhaust_fan          
      exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
      exhaust_fan.setName("#{source_zone.name.to_s} Zone Transfer Air Dummy Exhaust Fan")
      exhaust_fan.setFanEfficiency(1.0)
      exhaust_fan.setPressureRise(0.0)
      exhaust_fan.setMaximumFlowRate(exhaust_flow_rate)
      
      if couple_zone_exhaust_fan
        exhaust_fan.setSystemAvailabilityManagerCouplingMode("Coupled")
      else
        exhaust_fan.setSystemAvailabilityManagerCouplingMode("Decoupled")
      end
      
      # set flow rate schedule if defined (default is always on)
      # error checking already occured earlier in measure
      exhaust_fan.setFlowFractionSchedule(flow_sch)
      runner.registerInfo("Source Zone Exhaust Fan Schedule set to #{flow_sch.name.to_s}")
      
      # add exhaust fan to thermal zone
      exhaust_fan.addToThermalZone(source_zone)
      runner.registerInfo("Added zone exhaust fan to source zone #{source_zone.name.to_s}")
    end
    
    # add output reports
    if add_zone_mixing_variables
      OpenStudio::Model::OutputVariable.new("Zone Mixing Volume", model)
      OpenStudio::Model::OutputVariable.new("Zone Mixing Current Density Air Volume Flow Rate", model)
      OpenStudio::Model::OutputVariable.new("Zone Mixing Standard Density Air Volume Flow Rate", model)
      OpenStudio::Model::OutputVariable.new("Zone Mixing Mass Flow Rate", model)
      OpenStudio::Model::OutputVariable.new("Zone Mixing Receiving Air Mass Flow Rate", model)
      OpenStudio::Model::OutputVariable.new("Zone Mixing Source Air Mass Flow Rate", model)
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getZoneMixings.size} Zone Mixing Objects.")

    return true

  end
  
end

# register the measure to be used by the application
TransferAirZoneMixing.new.registerWithApplication