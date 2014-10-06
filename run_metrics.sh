#!/bin/bash

#export INETCREDENTIALS=xxxxxxxxxxxxxxx
#export PT_TOKEN=xxxxxxxxxxxxxxx
export RUBY=/home/attuser/.rvm/rubies/jruby-1.7.15/bin/ruby
export MYDIR=/home/attuser/git/defect-metrics

cd $MYDIR
$RUBY $MYDIR/metrics.rb

lftp sftp://$INETCREDENTIALS@onyx  -e "cd /var/www/wordpress/wp-content/uploads/2013/02; lcd $MYDIR; put style.css; put defect_status.html; put all_defect_info.html; put qa.html; put defect_backlog.png; put defect_backlog.html; put defect_arrivals.png; put defect_arrivals.html; bye"
