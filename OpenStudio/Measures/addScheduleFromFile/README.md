addScheduleFromFile
==================

###Import a csv file of schedule values into an OpenStudio model as a ScheduleInterval object

# Usage
**ruby addScheduleFromFile.rb ARGV[0] ARGV[1] ARGV[2]**

**ARGV[0] - Path to OpenStudio Model**

**ARGV[1] - Path to csv file**

**ARGV[2] - Schedule name**

# Examples
### ```ruby addScheduleFromFile.rb 'C:\path\to\model.osm' 'C:\path\to\values.csv' 'ScheduleName' -k```
### ```ruby addScheduleFromFile.rb 'base.osm' 'values.csv' 'MySchedule' -k```