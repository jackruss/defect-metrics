defect-metrics
==============

This script will pull story data from Pivotal Tracker and generate HTML pages and PNG graphs to reflect metric and status data for those stories.  Specifically, it looks in a set of repositories (currently hard-coded) for any story with the "qa_metric" tag and reads data from those stories.

Prerequisite: The "PT_TOKEN" environment variable must contain a Pivotal Tracker authentication token in order to access PT.

The script can generate output locally by running `ruby metrics.rb` from the command line.

To generate data and upload files to the CK inet, run `./run_metrics.sh`
