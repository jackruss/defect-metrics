#!/bin/bash

export RUBY=/home/attuser/.rvm/rubies/jruby-1.7.15/bin/ruby
export MYDIR=/home/attuser/git/defect-metrics
$RUBY $MYDIR/metrics.rb

lftp sftp://$INETCREDENTIALS@onyx  -e "cd /var/www/wordpress/wp-content/uploads/2013/02; lcd $MYDIR; put defect_status.html; put style.css; bye"
