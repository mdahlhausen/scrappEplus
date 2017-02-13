######################################################################
# == Synopsis 
#
#  Import a csv file of schedule values into an OpenStudio model with as a ScheduleInterval object.
#  Currently, only available schedule is  
#
# == Usage
#
#  ruby addScheduleFromFile.rb ARGV[0] ARGV[1] ARGV[2]
#
#  ARGV[0] - Path to OpenStudio Model
#
#  ARGV[1] - Path to csv file
#
#  ARGV[2] - Schedule name
#
# == Example
#
#   ruby addScheduleFromFile.rb 'C:\path\to\model.osm' 'C:\path\to\values.csv' 'ScheduleName' -k
######################################################################

require 'openstudio'
require 'csv'
require 'optparse'
require 'ostruct'
if ARGV.length < 3
  puts "Usage: ruby addScheduleFromFile.rb 'C:\\path\\to\\model.osm' 'C:\\path\\to\\file.csv' 'ScheduleName' -options"
  exit false
end

class Optparse
  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.verbose = false

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: ruby addScheduleFromFile.rb 'C:\\path\\to\\model.osm' 'C:\\path\\to\\eplusout.sql' 'ScheduleName'"

      opts.separator ""
      opts.separator " Options:"

      # Optionally keep original osm input file (and schedule)
      options.keep = false
      opts.on( '-k', '--keep', "Keep original osm file and schedule" ) do
        options.keep = true
      end      

      # No argument, shows at tail.  This will print an options summary.
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

    end

    opts.parse!(args)
    options
  end  # parse()

end  # class Optparse

options = Optparse.parse(ARGV)

#import the model and forward translate it
modelPath = OpenStudio::Path.new(ARGV[0])
modelPath = OpenStudio::system_complete(modelPath)
translator = OpenStudio::OSVersion::VersionTranslator.new
model = translator.loadModel(modelPath)
if model.empty?
  puts "Model cannot be read"
  return false
end
model = model.get

# load the csv file
csvPath = OpenStudio::Path.new(ARGV[1])
if not csvPath
  puts "csvFile #{csvPath} not found"
  return false
end
csvValues = CSV.read("#{csvPath}", {headers: false, converters: :float})

# Create values for the timeseries
values = OpenStudio::Vector.new(8760, 0.0)
for i in (0..8759)
  values[i] = csvValues[i][0]
end

startDate = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
interval = OpenStudio::Time.new(0,1,0)
timeseries = OpenStudio::TimeSeries.new(startDate, interval, values, "W")
schedule = OpenStudio::Model::ScheduleInterval::fromTimeSeries(timeseries, model)

if schedule.empty?
  puts "Could not create schedule from '#{csvPath}'"
  return false
end
schedule = schedule.get
scheduleName = ARGV[2]
schedule.setName(scheduleName)

#write new model   
if options.keep
  # write to working directory  
  outPath = modelPath.parent_path / OpenStudio::Path.new("out.osm")
  model.save(outPath, true)
else
  # overwrite existing file
  outDir = File.dirname(modelPath.to_s)
  outName = File.basename(modelPath.to_s, '.osm')
  outPath = OpenStudio::Path.new(outDir) / OpenStudio::Path.new(outName + ".osm")
  model.save(outPath, true)
end