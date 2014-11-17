defect-metrics
==============

This script will pull story data from Pivotal Tracker and generate HTML pages and PNG graphs to reflect metric and status data for those stories.  Specifically, it looks in a set of repositories (currently hard-coded) for any story with the "qa_metric" tag and reads data from those stories.

The script can generate output locally by running `ruby metrics.rb` from the command line.

To generate data and upload files to the CK inet, run `./run_metrics.sh`

PREREQUISITES: 

- The "PT_TOKEN" environment variable must contain a Pivotal Tracker authentication token in order to access PT.
- The "INET_CREDENTIALS" environment variable must contain inet credentials in the form "user:password" in order to upload to the inet
