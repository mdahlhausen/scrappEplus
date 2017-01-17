# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

#load dependencies
require "#{File.dirname(__FILE__)}/resources/OsLib_HelperMethods"
require "#{File.dirname(__FILE__)}/resources/OsLib_HVAC"
require 'csv'

#start the measure
class AssignZonesToAirLoopByCsv < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Assign Zones to AirLoop by csv"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #file path to air loop assignment
    file_path = OpenStudio::Ruleset::OSArgument.makeStringArgument("file_path", true)
    file_path.setDisplayName("Enter the path to the file:")
    file_path.setDescription("Example: 'C:\\Projects\\AHU_assignment.csv'")
    args << file_path

    #make a choice argument for type of AirTerminal
    chs_names = OpenStudio::StringVector.new
    chs_names << "AirTerminal:SingleDuct:Uncontrolled"
    chs_names << "AirTerminal:SingleDuct:VAV:NoReheat"
    #chs_names << "AirTerminal:SingleDuct:VAV:Reheat(Elec)"
    #chs_names << "AirTerminal:SingleDuct:VAV:Reheat(Gas)"
    chs_names << "AirTerminal:SingleDuct:VAV:Reheat(HW)"
    #chs_names << "AirTerminal:SingleDuct:ConstantVolume:Reheat(Elec)"
    #chs_names << "AirTerminal:SingleDuct:ConstantVolume:Reheat(Gas)"
    chs_names << "AirTerminal:SingleDuct:ConstantVolume:Reheat(HW)"

    default_air_terminal_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('default_air_terminal_type', chs_names, true)
    default_air_terminal_type.setDisplayName("Select default type of AirTerminal:")
    default_air_terminal_type.setDefaultValue("AirTerminal:SingleDuct:Uncontrolled")
    args << default_air_terminal_type
       
    #select plant loops
    plantLoops = model.getPlantLoops
    plantLoops_handle = OpenStudio::StringVector.new
    plantLoops_displayName = OpenStudio::StringVector.new
    plantLoops.each do |plantLoop|
      plantLoops_handle << plantLoop.handle.to_s
      plantLoops_displayName << plantLoop.name.to_s
    end       
    
    # make an argument for heating loop, if applicable
    heating_plant_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("heating_plant_loop", plantLoops_handle, plantLoops_displayName,false)
    heating_plant_loop.setDisplayName("Select the heating plant loop for use for air terminals, if applicable.")
    args << heating_plant_loop
     
    # make an argument for cooling loop, if applicable
    # cooling_plant_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("cooling_plant_loop", plantLoops_handle, plantLoops_displayName,false)
    # cooling_plant_loop.setDisplayName("Select the cooling plant loop for use with the air terminals, if applicable.")
    # cooling_plant_loop.setDefaultValue(plantLoops_displayName[0])
    # args << cooling_plant_loop
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    ### START INPUTS
    #assign the user inputs to variables    
    file_path = runner.getStringArgumentValue('file_path', user_arguments)  
    default_air_terminal_type = runner.getStringArgumentValue('default_air_terminal_type', user_arguments)    

    # check the file path for reasonableness
    if file_path.empty?
      runner.registerError("Empty path was entered.")
      return false
    end
    
    # Strip out the potential leading and trailing quotes
    file_path.gsub!('"','')
    
    if (default_air_terminal_type == "AirTerminal:SingleDuct:VAV:Reheat(HW)") || (default_air_terminal_type == "AirTerminal:SingleDuct:ConstantVolume:Reheat(HW)")
      heating_plant_loop = runner.getOptionalWorkspaceObjectChoiceValue("heating_plant_loop",user_arguments,model) #model is passed in because of argument type     
      #check the heating_plant_loop for reasonableness
      if heating_plant_loop.empty?
        runner.registerError("The selected plant loop was not found in the model. It may have been removed by another measure.")
        return false
      else
        if not heating_plant_loop.get.to_PlantLoop.empty?
          heating_plant_loop = heating_plant_loop.get.to_PlantLoop.get
          runner.registerInfo("Using plant loop #{heating_plant_loop.name.to_s} for reheat terminals")
        else
          runner.registerError("Script Error - argument not showing up as plant loop.")
          return false
        end
      end     
    end
    
    # cooling_plant_loop = runner.getOptionalWorkspaceObjectChoiceValue("cooling_plant_loop",user_arguments,model) #model is passed in because of argument type
    #check the cooling_plant_loop for reasonableness
    # if cooling_plant_loop.empty?
        # runner.registerError("The selected plant loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        # return false
      # end
    # else
      # if not cooling_plant_loop.get.to_PlantLoop.empty?
        # cooling_plant_loop = cooling_plant_loop.get.to_PlantLoop.get
      # else
        # runner.registerError("Script Error - argument not showing up as plant loop.")
        # return false
      # end
    # end  #end of if cooling_plant_loop.empty?
    ### END INPUTS
    
    ### START REPORT INITIAL CONDITIONS
    OsLib_HVAC.reportConditions(model, runner, "initial")
    ### END REPORT INITIAL CONDITIONS

    ### START AIR TERMINAL ASSIGNMENT
    zones = model.getThermalZones
    airloops = model.getAirLoopHVACs
    if !File.exist? file_path
      runner.registerError("The file at path #{file_path} doesn't exist.")
      return false
    else
      raw_data =  CSV.table(file_path)
      # Transform to array of hashes
      variables = raw_data.map { |row| row.to_hash }
      variables.each do |var|
        zone_name = var[:thermal_zone]
        airloop_name = var[:airloop]
        
        zone = zones.select { |z| z.name.to_s == zone_name }
        if zone[0].nil?
          runner.registerError("Unable to find zone #{zone_name} in the model")
          return false
        else
          zone = zone[0]
        end        
        
        next if airloop_name.nil?

        # remove from existing air loop
        airloops.each do |a|
          a.removeBranchForZone(zone)
        end

        airloop = airloops.select { |a| a.name.to_s == airloop_name }
        if airloop[0].nil?
          runner.registerError("Unable to find airloop #{airloop_name} in the model")
          return false
        else
          airloop = airloop[0]
        end
        
        #override option here
        air_terminal_type = default_air_terminal_type

        if air_terminal_type == "AirTerminal:SingleDuct:VAV:NoReheat"
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule())
        elsif air_terminal_type == "AirTerminal:SingleDuct:VAV:Reheat(HW)"
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule())
          heating_coil.setName("VAV Reheat Coil - #{zone.name.to_s}")
          heating_plant_loop.addDemandBranchForComponent(heating_coil)
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule(), heating_coil)
        elsif air_terminal_type == "AirTerminal:SingleDuct:ConstantVolume:Reheat(HW)"
          heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule())
          heating_coil.setName("CAV Reheat Coil - #{zone.name.to_s}")
          heating_plant_loop.addDemandBranchForComponent(heating_coil)
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctConstantVolumeReheat.new(model, model.alwaysOnDiscreteSchedule(), heating_coil)
        else #air_terminal_type == "AirTerminal:SingleDuct:Uncontrolled"
          air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule())
        end
        air_terminal.setName("AirTerminal - #{zone.name.to_s}")

        # attach new terminal to the zone and to the airloop
        runner.registerInfo("Attaching AirTerminal for zone '#{zone.name.to_s}' to airloop '#{airloop.name.to_s}'")
        airloop.addBranchForZone(zone, air_terminal.to_StraightComponent)
      end      
    end
    ### END AIR TERMINAL ASSIGNMENT    
    
    ### START REPORT FINAL CONDITIONS
    OsLib_HVAC.reportConditions(model, runner, "final")
    ### END REPORT FINAL CONDITIONS
    return true
  end #end the run method
end #end the measure

#this allows the measure to be used by the application
AssignZonesToAirLoopByCsv.new.registerWithApplication