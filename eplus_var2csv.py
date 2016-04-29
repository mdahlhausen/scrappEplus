#eplus_var2csv.py
#A simple python program to extract output variables from an EnergyPlus sql file.
#Author: Matthew Dahlhausen, Integral Group 2016

#TODOs
# extend this with TkInter or Pyjamas GUI, multiple variable selection
# add in try/catch exceptions
# populate a list of available inputs, select from drop down, ctrl to select multiple
# export to the same or separate csv files (with check to make sure it doesn't extend too far)
# little logo

import sqlite3
import os
import csv

print('\n**************************:')
print('AVAILABLE SQL FILES:')
sql_files = []

for file in os.listdir(os.getcwd()):
  if file.endswith(".sql"):
    sql_files.append(file)
    print(file)

if not sql_files:
  print('NO .sql FILE FOUND IN THIS DIRECTORY. PLACE THE SQL FILE IN THE SAME DIRECTORY AS THIS PYTHON SCRIPT AND TRY AGAIN.')
  quit()
	
out_sql = input('\nEnter sql filename (press enter to use "' + sql_files[0] + '"):')
if not out_sql:
  out_sql = sql_files[0]

#validate input, try connecting to database
sql_path = os.path.join(os.getcwd(),out_sql)
conn = sqlite3.connect(sql_path)
c = conn.cursor()

print('\n**************************:')
print('AVAILABLE OUTPUT VARIABLES:')
vars_avail = c.execute('SELECT DISTINCT KeyValue,VariableName FROM ReportVariableDataDictionary').fetchall()

for v in vars_avail:
  print(v)
key_value = input('Enter a Key Value (example: ' + vars_avail[0][0] + '):')
variable_name = input('Enter a Variable (example: ' + vars_avail[0][1] + '):')
#print('selected',key_value,',',variable_name);

run_period_index = c.execute('SELECT EnvironmentPeriodIndex FROM EnvironmentPeriods WHERE EnvironmentType=3').fetchone()[0]
variable_index = c.execute("SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary WHERE VariableName=:variable_name AND KeyValue=:key_value",{"variable_name":variable_name, "key_value":key_value}).fetchone()[0]
values = c.execute("SELECT Value FROM ReportData WHERE TimeIndex IN (SELECT TimeIndex FROM Time WHERE Interval=60 AND EnvironmentPeriodIndex=:run_period_index) AND ReportDataDictionaryIndex=:variable_index",{"run_period_index":run_period_index, "variable_index":variable_index}).fetchall()
for v in values: 
  v = v[0]
  
output_filename = key_value + '_' + variable_name + '.csv'
#get rid of invalid characters for filenames
#could be done much more cleanly with re library, but don't want to import that
output_filename = output_filename.replace('/','')
output_filename = output_filename.replace(':','')
output_filename = output_filename.replace('*','')
output_filename = output_filename.replace('?','')
output_filename = output_filename.replace('"','')
output_filename = output_filename.replace('<','')
output_filename = output_filename.replace('>','')
output_filename = output_filename.replace('|','')

with open(output_filename, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(values)
print('values saved to: ' + output_filename);