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

# I got problems
### 1) Check to make sure the numbers are float - e.g. 1.0 instead of 1
### 2) Make sure your data is 8760.  It'll give :(  if < 8760, and will just omit the end if > 8760.