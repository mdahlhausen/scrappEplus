class AssignAndNameZonesToUnassignedSpaces < OpenStudio::Ruleset::ModelUserScript

  def name
    return "Make Thermal Zones for All Spaces"
  end
  
  def arguments(model)
    result = OpenStudio::Ruleset::OSArgumentVector.new
    return result
  end
    
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #This will remove thermal zones without spaces or equipment
    thermal_zones = model.getThermalZones
    thermal_zone_handles_to_remove = OpenStudio::UUIDVector.new
    thermal_zones.each do |thermal_zone|
      if thermal_zone.spaces.empty? && thermal_zone.equipment.empty? && thermal_zone.isRemovable
        thermal_zone_handles_to_remove << thermal_zone.handle
      end
    end
    
    if not thermal_zone_handles_to_remove.empty?
      model.removeObjects(thermal_zone_handles_to_remove)
      #runner.registerFinalCondition("Removing #{thermal_zone_handles_to_remove.size} thermal zones.")
    else
      #runner.registerFinalCondition("No unused thermal zones to remove.")
    end
    
    # get all spaces
    spaces = model.getSpaces
    
    runner.createProgressBar("Creating Zones for Untagged Spaces")
    num_total = spaces.size
    num_complete = 0

    # loop through spaces
    spaces.each do |space| # this is going through all, not just selection
      if space.thermalZone.empty?
        newthermalzone = OpenStudio::Model::ThermalZone.new(model)
        new_name = "TZ_" + space.name.to_s
        newthermalzone.setName(new_name)
        space.setThermalZone(newthermalzone)
        runner.registerInfo("Created " + newthermalzone.briefDescription + " and assigned " + space.briefDescription + " to it.")
      end

      num_complete += 1
      runner.updateProgress((100*num_complete)/num_total)
    end

    runner.destroyProgressBar
    
  end

end

# this call registers your script with the OpenStudio SketchUp plug-in
AssignAndNameZonesToUnassignedSpaces.new.registerWithApplication
